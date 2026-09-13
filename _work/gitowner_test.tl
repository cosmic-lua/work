#!/usr/bin/env cosmic
-- The owner rule at the WRITE: `new --repo` and `set --repo` refuse a
-- slug under a foreign owner before it lands, so stale data stops
-- entering the board, and accept it when the spec — the one being
-- filed, or the one the item already has — names it under
-- `## Access`. The same rule read back at the ready bar, for a value
-- written before it existed, is in `_work/gitgate_test.tl`; this is
-- the sibling `_work/gitgraph_test.tl`'s file cap sends the graph
-- verbs' half to.

local check = require("cosmic.check")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local ready = require("_work.gitready")
local specmod = require("_work.spec")
local storewrite = require("_work.storewrite")
local graph = require("_work.gitgraph")
local owner = require("_work.gitowner")
local publish = require("_work.publish")
local refs = require("_work.refs")
local store = require("_work.store")

--- A cross-owner declaration as it actually reaches the owner rule as
--- of format 5: inside the Change blob, which is the shape an
--- unmigrated format-4 `spec.md` reads back as. `## Access` is no
--- longer a section a WRITE may carry — `spec.split` refuses it, naming
--- the field that replaces it (`_work/spec_test.tl`) — so the rule is
--- exercised against the data that carries the declaration rather than
--- through the verb that no longer accepts one.
local ACCESS_PROSE < const >: itemtree.Spec = {
  change = "Do exactly this.\n\n## Access\n"
  .. "- whilp/cosmopolitan (the fork the diff deliberately targets)\n",
  non_goals = "Not that.\n",
}

--- A board that reads its origin as `cosmic-lua/cosmic`, with one
--- placed root to file under.
local function github_board(name: string): store.Store, string
  local s = fixture.init_shared("write-" .. name)
  fixture.github_origin(s, "cosmic-lua/cosmic")
  local root = fixture.root_with_leaf(s)
  return s, root
end

--- The ids on a board, for the set difference a `new` is read from.
local function ids(s: store.Store): {string: boolean}
  local out: {string: boolean} = {}
  for _, i in ipairs(check.must(store.list(s))) do
    out[i.id] = true
  end
  return out
end

--- Capture what a verb prints, so a test can pin its verdict line.
local function capture(f: function(): integer): integer, string
  local lines: {string} = {}
  local real = _G.print
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(f)
  _G.print = real
  if not ok then
    error(result, 0)
  end
  -- cast: pcall erases the callee's return type; f is typed to return integer
  return result as integer, table.concat(lines, "\n")
end

-- The board's owner is read from the origin's https form.
local function test_board_owner_is_the_origins_owner()
  local s = github_board("owner")
  assert(owner.board_owner(s) == "cosmic-lua", "got: "
    .. tostring(owner.board_owner(s)))
end

-- Repository identity follows the caller-selected board remote; `origin` is
-- only the default, not part of the data model.
local function test_board_owner_uses_the_configured_non_origin_remote()
  local s = github_board("configured-owner")
  fixture.git(s.root, {"remote", "add", "upstream",
      "https://github.com/alternate/board.git"})
  assert(refs.use_remote(s.root, "upstream"))
  assert(owner.board_owner(s) == "alternate", "got: "
    .. tostring(owner.board_owner(s)))
end

-- `new --repo` under a foreign owner is refused with the value and the
-- repair, and nothing is filed; the same owner as the board lands.
local function test_new_refuses_a_foreign_owner_repo()
  local s, root = github_board("new")
  local before = ids(s)
  local code, out = capture(function(): integer
      return graph.cmd_new(s, "a fork-side slice", root, nil, "whilp/cosmopolitan")
    end)
  assert(code ~= 0, "a foreign owner is refused")
  assert(out:find("REFUSED: repo: whilp/cosmopolitan", 1, true)
    and out:find("--repo cosmic-lua/cosmopolitan", 1, true),
    "the verdict names the value and the repair: " .. out)
  for id in pairs(ids(s)) do
    assert(before[id], "and nothing was filed: " .. id)
  end
  assert(graph.cmd_new(s, "a fork-side slice", root, nil,
      "cosmic-lua/cosmopolitan") == 0, "the board's own owner lands")
  fixture.caller_publish(s)
end

-- Prose naming the slug under `## Access` is the escape at file time:
-- the item lands with the foreign repo, and its spec says why.
local function test_new_accepts_a_foreign_owner_the_spec_declares()
  local s, root = github_board("new-declared")
  local before = ids(s)
  assert(graph.cmd_new(s, "a fork-side slice", root, ACCESS_PROSE,
      "whilp/cosmopolitan") == 0, "a declared cross-owner repo lands")
  fixture.caller_publish(s)
  local filed: string = nil
  for id in pairs(ids(s)) do
    if not before[id] then filed = id end
  end
  assert(filed ~= nil and check.must(store.load(s, filed)).repo
    == "whilp/cosmopolitan", "with the field as given")
end

-- `set --repo` asks the same rule of the item's CURRENT spec: refused
-- bare, accepted once the spec names the slug.
local function test_set_refuses_a_foreign_owner_repo_until_declared()
  local s, root = github_board("set")
  local leaf = fixture.file_item(s, "a slice", root)
  local code, out = capture(function(): integer
      return graph.cmd_set(s, leaf, nil, "whilp/cosmopolitan", nil)
    end)
  assert(code ~= 0, "a foreign owner is refused")
  assert(out:find(("gitboard set %s --repo cosmic-lua/cosmopolitan")
      :format(leaf:sub(1, 8)), 1, true),
    "the verdict names the repair: " .. out)
  assert(check.must(store.load(s, leaf)).repo == "", "and nothing was written")
  -- `## Access` is no longer a section a write may carry, so the
  -- declaration is put where the rule reads it — the shape an
  -- unmigrated `spec.md` reads back as — rather than through `spec`,
  -- which refuses it by name.
  local path = fs.join(fixture.tmpdir, "write-set-access.md")
  assert(fs.write(path, specmod.document(ACCESS_PROSE)))
  local refused, rerr = specmod.split("## Change\nx\n\n## Access\n- a/b\n")
  assert(refused == nil and rerr:find("declared field", 1, true) ~= nil, rerr)
  local target = check.must(store.load(s, leaf))
  assert(storewrite.save(s, target, "fixture: declared access", ACCESS_PROSE))
  assert(publish.publish(s))
  fixture.caller_publish(s)
  assert(graph.cmd_set(s, leaf, nil, "whilp/cosmopolitan", nil) == 0,
    "declared under the item's own spec, the field is accepted")
  fixture.caller_publish(s)
  assert(check.must(store.load(s, leaf)).repo == "whilp/cosmopolitan")
end

-- Local-only boards have no owner and the write is never refused —
-- which is also why every existing fixture is unchanged.
local function test_a_local_only_board_writes_any_repo()
  local s = fixture.init_state_repo("write-local")
  local root = fixture.file_item(s, "an outcome", "")
  assert(graph.cmd_new(s, "a slice", root, nil, "whilp/cosmopolitan") == 0,
    "no origin, no owner, no refusal")
end

-- The FIELD is the other spelling of the same declaration, and the
-- rule takes the union: `set --access` grants the cross-owner repo
-- with no prose at all. Without the union this is the window PR #154
-- opened — the section refused on write, the field unread — where the
-- refusal's own repair text names a command that does not work.
local function test_the_access_field_grants_a_foreign_owner_repo()
  local s, root = github_board("field-grant")
  local leaf = fixture.file_item(s, "a slice", root)
  local code, out = capture(function(): integer
      return graph.cmd_set(s, leaf, nil, "whilp/cosmopolitan", nil)
    end)
  assert(code ~= 0, "undeclared, the cross-owner repo is refused: " .. out)
  assert(out:find("--access whilp/cosmopolitan", 1, true),
    "and the refusal names the declaring command: " .. out)
  assert(graph.cmd_set(s, leaf, nil, nil, nil, nil, nil, nil, nil,
      {"whilp/cosmopolitan"}) == 0, "the field is declarable on its own")
  fixture.caller_publish(s)
  assert(#check.must(store.load(s, leaf)).access == 1,
    "the access field, not touches, is what got set")
  fixture.caller_publish(s)
  assert(graph.cmd_set(s, leaf, nil, "whilp/cosmopolitan", nil) == 0,
    "declared as a field, with no prose, the repo is accepted")
  fixture.caller_publish(s)
  assert(check.must(store.load(s, leaf)).repo == "whilp/cosmopolitan")
end

-- Both in ONE call, which is what the refusal's repair text invites a
-- caller to type. The `--repo` check runs before `--access` is
-- applied, so it reads the EFFECTIVE list or refuses a call that
-- declares exactly the access it needs.
local function test_repo_and_access_land_in_one_call()
  local s, root = github_board("field-one-call")
  local leaf = fixture.file_item(s, "a slice", root)
  assert(graph.cmd_set(s, leaf, nil, "whilp/cosmopolitan", nil, nil, nil,
      nil, nil, {"whilp/cosmopolitan"}) == 0,
    "one call declaring the access it needs is not refused")
  fixture.caller_publish(s)
  local got = check.must(store.load(s, leaf))
  assert(got.repo == "whilp/cosmopolitan", "the repo landed")
  assert(#got.access == 1 and got.access[1] == "whilp/cosmopolitan",
    "and so did the declaration")
end

-- The ready bar reads the same union, so an item whose spec REACHES a
-- repository it declares only as a field is not reported undeclared.
local function test_the_ready_bar_reads_the_access_field()
  local reaching: itemtree.Spec = {
    change = "Read `https://github.com/whilp/cosmopolitan/blob/main/x.c`.\n",
    non_goals = "",
  }
  local it: item.Item = {id = "x", title = "t", repo = "cosmic-lua/work",
    access = {}, touches = {}, depends_on = {}, builders = {}, speccers = {},
    order = {}}
  local body = specmod.document(reaching)
  assert(#ready.undeclared_repos(it, body) == 1,
    "undeclared, the reached repo is reported")
  it.access = {"whilp/cosmopolitan"}
  assert(#ready.undeclared_repos(it, body) == 0,
    "declared as a field, it is not")
end
