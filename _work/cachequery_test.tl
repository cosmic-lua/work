#!/usr/bin/env cosmic
-- `_work.cachequery`: the `lanes` table round trip, and the
-- `similar_lines`/`cmd_find` wrappers that open the cache, query it,
-- and close it again.

local cache = require("_work.cache")
local cachedb = require("_work.cachedb")
local cachequery = require("_work.cachequery")
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local gitobj = require("_work.gitobj")
local refs = require("_work.refs")
local tail = require("_work.tail")

local init_state_repo = fixture.init_state_repo
local file_item = fixture.file_item

local function test_lanes_read_write_round_trip()
  local s = init_state_repo("lanes-roundtrip")
  assert(next(cachequery.lanes_read(s.root)) == nil,
    "a board with no cache file has no observation yet")
  assert(cachequery.lanes_write(s.root, {["release.yml"] = "success"}))
  local facts = cachequery.lanes_read(s.root)
  assert(facts["release.yml"] == "success", tostring(facts["release.yml"]))
end

local function test_lanes_write_replaces_a_prior_conclusion()
  local s = init_state_repo("lanes-replace")
  assert(cachequery.lanes_write(s.root, {["release.yml"] = "failure"}))
  assert(cachequery.lanes_write(s.root, {["release.yml"] = "success"}))
  local facts = cachequery.lanes_read(s.root)
  assert(facts["release.yml"] == "success", tostring(facts["release.yml"]))
end

local function test_similar_lines_and_cmd_find_go_through_the_cache()
  local s = init_state_repo("cache-find")
  file_item(s, "add full text search over the board", "")
  local lines = cachequery.similar_lines(s.root, "add full text search over items")
  assert(#lines >= 1, "at least one similar line")
  assert(lines[1]:match("^similar: «%w[%w_-]*» .+$") ~= nil, lines[1])

  local seen: {string} = {}
  local old_print = _G.print
  _G.print = function(msg: any) seen[#seen + 1] = tostring(msg) end
  local rc = cachequery.cmd_find(s.root, "full text search")
  _G.print = old_print
  assert(rc == 0, "a hit is a success")
  assert(seen[#seen] == "gitboard-find: 1 hit(s)", seen[#seen])
end

local function test_cmd_find_reports_zero_hits_without_failing()
  local s = init_state_repo("cache-find-zero")
  file_item(s, "something else entirely", "")
  local seen: {string} = {}
  local old_print = _G.print
  _G.print = function(msg: any) seen[#seen + 1] = tostring(msg) end
  local rc = cachequery.cmd_find(s.root, "nonexistentword")
  _G.print = old_print
  assert(rc == 0, "zero hits is not a failure")
  assert(seen[#seen] == "gitboard-find: 0 hit(s)", seen[#seen])
end

-- `resolve_tail`: the four shapes a handle lookup against the cache
-- can take — no file yet, a miss, a single hit, and an ambiguous one
-- — each falling through ("" error) or refusing (a non-empty one) as
-- `_work.gitboard.resolve_id` expects.

local function test_resolve_tail_falls_through_when_the_cache_is_absent()
  local s = init_state_repo("cache-resolve-absent")
  local id, err = cachequery.resolve_tail(s.root, "«ZZZZ_ZZZZ»")
  assert(id == nil and err == "", "no cache file yet, so this falls through")
end

local function test_resolve_tail_falls_through_on_a_miss()
  local s = init_state_repo("cache-resolve-miss")
  file_item(s, "an item", "") -- warms the cache as a side effect of `new`
  local id, err = cachequery.resolve_tail(s.root, "ZZZZZZZZ")
  assert(id == nil and err == "", "no row carries this tail")
end

local function test_resolve_tail_resolves_a_single_hit()
  local s = init_state_repo("cache-resolve-hit")
  local id = file_item(s, "an item", "")
  local got, err = cachequery.resolve_tail(s.root, tail.handle(id))
  assert(got == id, tostring(got))
  assert(err == "", err)
end

local function test_resolve_tail_refuses_a_cache_row_ambiguity()
  local s = init_state_repo("cache-resolve-ambiguous")
  local c = check.must(cache.open(s.root))
  assert(c.db:exec("INSERT INTO items (id, title) VALUES (?, ?)",
      {"0000000000000000000AAABBBBB", "one"}))
  assert(c.db:exec("INSERT INTO items (id, title) VALUES (?, ?)",
      {"1111111111111111111AAABBBBB", "two"}))
  check.must(cache.close(c))
  local id, err = cachequery.resolve_tail(s.root, "AAABBBBB")
  assert(id == nil, "two rows share this tail")
  -- Both rows share this tail, so the refusal renders the same handle
  -- twice — the candidates as handles, not bare tails or ids.
  assert(err == "AAABBBBB is ambiguous: «AAAB_BBBB» «AAAB_BBBB»", err)
end

--- The well-known empty tree's sha — good enough content for a bare
--- ref, which `resolve_glob` reads only the name and sha of.
local EMPTY_TREE < const > = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"

--- A bare item ref, no store involved — everything `resolve_glob`
--- reads.
--- @param root string The repository root
--- @param id string The item id to file it under
local function file_ref(root: string, id: string)
  local sha = check.must(gitobj.commit_tree(root, {
        tree = EMPTY_TREE, parents = {}, message = "x",
        author_name = "t", author_email = "t@example.com",
        committer_name = "t", committer_email = "t@example.com",
      }))
  check.must(refs.update_ref(root, "refs/heads/items/" .. id, sha, refs.ZERO_SHA))
end

-- The item's own spec bar: whichever path answers an ambiguous tail —
-- the cache (`resolve_tail`) or the ref-glob fallback
-- (`tail.resolve_glob`) — must refuse with the identical message
-- text, not merely the word "ambiguous": both render every colliding
-- candidate as its own handle, in id order, through the shared
-- `tail.join_handles` helper. File the SAME two colliding ids both as
-- raw refs (what the glob reads) and as cache rows (what the cache
-- reads), so one input exercises both paths, and compare the messages
-- verbatim.
local function test_cache_and_glob_paths_refuse_the_same_ambiguity_identically()
  local s = init_state_repo("cache-glob-ambiguity-match")
  local one = "0000000000000000000AAABBBBB"
  local other = "1111111111111111111AAABBBBB"
  -- Build and populate the cache against the still-empty board first
  -- — `cache.open` rebuilds from the real ref layout, and the fake
  -- bare refs `file_ref` files below carry no item "meta" for it to
  -- read, so they must land only AFTER the cache is closed.
  local c = check.must(cache.open(s.root))
  assert(c.db:exec("INSERT INTO items (id, title) VALUES (?, ?)", {one, "one"}))
  assert(c.db:exec("INSERT INTO items (id, title) VALUES (?, ?)", {other, "two"}))
  check.must(cache.close(c))

  local cache_id, cache_err = cachequery.resolve_tail(s.root, "AAABBBBB")
  assert(cache_id == nil, "two cache rows share this tail")

  cachedb.wipe(s.root)
  file_ref(s.root, one)
  file_ref(s.root, other)
  local glob_id, glob_err = tail.resolve_glob(s.root, "AAABBBBB")
  assert(glob_id == nil, "two refs share this tail")

  assert(cache_err:find("ambiguous", 1, true), cache_err)
  assert(glob_err:find("ambiguous", 1, true), glob_err)
  assert(cache_err == glob_err,
    ("cache and glob refusals must render identically:\ncache: %s\nglob:  %s")
    :format(cache_err, glob_err))
end
