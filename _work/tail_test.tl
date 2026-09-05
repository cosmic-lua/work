#!/usr/bin/env cosmic
-- tail is mostly a pure derivation over an item's id: handle
-- rendering, shape detection, and resolve's exact/case-folded/refusal
-- arms are pinned directly, with no store and no git involved.
-- `resolve_glob` is the one exception — it reads the ref layout
-- directly, so its own tests below build a bare git repo and file raw
-- refs, never a store or a cache.

local check = require("cosmic.check")
local fixture = require("_work.fixture")
local gitobj = require("_work.gitobj")
local item = require("_work.item")
local refs = require("_work.refs")
local tail = require("_work.tail")

--- The well-known empty tree's sha — good enough content for a
-- `resolve_glob` test, which reads ref names and shas, never a tree.
local EMPTY_TREE < const > = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"

--- A bare item ref, no store and no cache involved: one commit over
--- the empty tree, filed directly under `refs/heads/items/<id>` —
--- everything `resolve_glob` reads.
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

--- A 27-char id with a chosen 8-char tail, so a test controls exactly
--- what `resolve` and `handle` see without depending on real KSUID
--- randomness. Two distinct fillers keep two same-tail items from
--- sharing one id.
--- @param t string The last 8 characters
--- @param filler string One character to pad the leading 19 with
--- @return string A 27-character id
local function make_id(t: string, filler?: string): string
  return (filler or "0"):rep(19) .. t
end

--- An item carrying exactly the given id.
--- @param id string The id
--- @param title string The title
--- @return item.Item The decoded item
local function make(id: string, title: string): item.Item
  return check.must(item.decode({id = id, title = title}))
end

local function test_handle_underscores_and_wraps_the_last_eight_characters()
  local id = make_id("Q4TX9GMD")
  assert(tail.handle(id) == "«Q4TX_9GMD»", tail.handle(id))
end

local function test_bare_is_the_handle_body_without_the_guillemets()
  local id = make_id("Q4TX9GMD")
  assert(tail.bare(id) == "Q4TX_9GMD", tail.bare(id))
  assert(tail.handle(id) == "«" .. tail.bare(id) .. "»",
    "handle wraps exactly what bare returns")
end

local function test_is_tail_shape_accepts_both_forms()
  assert(tail.is_tail_shape("s1WSJ6A3"), "divider-free")
  assert(tail.is_tail_shape("s1WS-J6A3"), "hyphenated after the 4th")
  assert(tail.is_tail_shape("«s1WS-J6A3»"), "a wrapped, hyphenated handle")
  assert(tail.is_tail_shape("«s1WS_J6A3»"), "a pasted, wrapped handle")
end

local function test_is_tail_shape_rejects_malformed_input()
  assert(not tail.is_tail_shape("s1WSJ6A"), "too short")
  assert(not tail.is_tail_shape("s1WSJ6A33"), "too long")
  assert(not tail.is_tail_shape("s1W-SJ6A3"), "hyphen in the wrong place")
  assert(not tail.is_tail_shape("s1WS.J6A3"), "period is not a valid divider")
  assert(not tail.is_tail_shape(""), "empty")
end

local function test_resolve_matches_exactly_hyphenated_or_not()
  local id = make_id("Q4TX9GMD")
  local all: {item.Item} = {make(id, "a slice")}
  assert(check.must(tail.resolve(all, "Q4TX9GMD")) == id, "hyphen-free")
  assert(check.must(tail.resolve(all, "Q4TX-9GMD")) == id, "hyphenated")
end

local function test_resolve_accepts_a_pasted_wrapped_handle()
  local id = make_id("d0x137YJ")
  local all: {item.Item} = {make(id, "a slice")}
  assert(check.must(tail.resolve(all, "«d0x1_37YJ»")) == id,
    "a copy-pasted rendered handle resolves like any other tail")
end

local function test_resolve_accepts_a_hyphenated_paste_for_backward_tolerance()
  local id = make_id("d0x137YJ")
  local all: {item.Item} = {make(id, "a slice")}
  assert(check.must(tail.resolve(all, "«d0x1-37YJ»")) == id,
    "a handle copied before the divider changed still resolves")
end

local function test_resolve_falls_back_to_case_folded_match()
  local id = make_id("Q4TXaBcD")
  local all: {item.Item} = {make(id, "a slice")}
  -- Neither typed form is an exact match (case differs), so both
  -- exercise the case-folded stage, not the exact one.
  assert(check.must(tail.resolve(all, "q4txabcd")) == id, "lowercased")
  assert(check.must(tail.resolve(all, "q4tx-abcd")) == id,
    "lowercased and hyphenated")
end

local function test_resolve_prefers_an_exact_match_over_a_folded_one()
  local exact = make_id("Q4TXABCD")
  local folded = make_id("q4txabcd", "1")
  local all: {item.Item} = {make(exact, "exact"), make(folded, "folded")}
  assert(check.must(tail.resolve(all, "Q4TXABCD")) == exact,
    "the exact stage wins before the folded stage is ever tried")
end

local function test_resolve_refuses_an_exact_ambiguity()
  local one = make_id("Q4TXABCD")
  local other = make_id("Q4TXABCD", "1")
  local all: {item.Item} = {make(one, "a"), make(other, "b")}
  local id, err = tail.resolve(all, "Q4TXABCD")
  assert(id == nil, "two items share this tail")
  assert(err:find("ambiguous", 1, true) and err:find("Q4TXABCD", 1, true), err)
end

local function test_resolve_refuses_a_folded_ambiguity()
  local one = make_id("Q4TXABCD")
  local other = make_id("q4txabcd", "1")
  local all: {item.Item} = {make(one, "a"), make(other, "b")}
  -- Mixed case matches neither exactly, so both candidates surface
  -- only once folding runs.
  local id, err = tail.resolve(all, "Q4TXabcd")
  assert(id == nil, "the fold matches both")
  assert(err:find("ambiguous", 1, true), err)
end

local function test_resolve_refuses_no_match()
  local all: {item.Item} = {make(make_id("Q4TX9GMD"), "a slice")}
  local id, err = tail.resolve(all, "ZZZZZZZZ")
  assert(id == nil, "no item carries that tail")
  assert(err:find("no item matches tail", 1, true), err)
end

local function test_resolve_glob_matches_a_tail_exactly()
  local s = fixture.init_state_repo("resolve-glob-exact")
  local id = make_id("Q4TX9GMD")
  file_ref(s.root, id)
  local resolved = check.must(tail.resolve_glob(s.root, "Q4TX9GMD"))
  assert(resolved.id == id, resolved.id)
  assert(resolved.ref == "refs/heads/items/" .. id, resolved.ref)
  assert(resolved.sha ~= "", "the single match's own sha leases the load that follows")
end

local function test_resolve_glob_refuses_an_exact_ambiguity()
  local s = fixture.init_state_repo("resolve-glob-ambiguous")
  file_ref(s.root, make_id("Q4TXABCD"))
  file_ref(s.root, make_id("Q4TXABCD", "1"))
  local resolved, err = tail.resolve_glob(s.root, "Q4TXABCD")
  assert(resolved == nil, "two items share this tail")
  assert(err:find("ambiguous", 1, true) and err:find("Q4TXABCD", 1, true), err)
end

local function test_resolve_glob_falls_back_to_case_folded_match()
  local s = fixture.init_state_repo("resolve-glob-fold")
  local id = make_id("Q4TXaBcD")
  file_ref(s.root, id)
  -- Neither typed form is an exact fnmatch, so both exercise the
  -- case-folded fallback, not the exact glob.
  local resolved = check.must(tail.resolve_glob(s.root, "q4txabcd"))
  assert(resolved.id == id, resolved.id)
  assert(resolved.ref == "refs/heads/items/" .. id, resolved.ref)
end

local function test_resolve_glob_refuses_a_folded_ambiguity()
  local s = fixture.init_state_repo("resolve-glob-fold-ambiguous")
  file_ref(s.root, make_id("Q4TXABCD"))
  file_ref(s.root, make_id("q4txabcd", "1"))
  local resolved, err = tail.resolve_glob(s.root, "Q4TXabcd")
  assert(resolved == nil, "the fold matches both")
  assert(err:find("ambiguous", 1, true), err)
end

local function test_resolve_glob_refuses_no_match()
  local s = fixture.init_state_repo("resolve-glob-nomatch")
  file_ref(s.root, make_id("Q4TX9GMD"))
  local resolved, err = tail.resolve_glob(s.root, "ZZZZZZZZ")
  assert(resolved == nil, "no item carries that tail")
  assert(err:find("no item matches tail", 1, true), err)
end

local function test_resolve_glob_skips_the_fallback_for_an_all_digit_tail()
  local s = fixture.init_state_repo("resolve-glob-digits")
  file_ref(s.root, make_id("Q4TX9GMD"))
  -- Case folding cannot change a match on an all-digit tail, so a
  -- miss refuses outright rather than paying for the fallback.
  local resolved, err = tail.resolve_glob(s.root, "00000000")
  assert(resolved == nil)
  assert(err:find("no item matches tail", 1, true), err)
end
