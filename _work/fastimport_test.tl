#!/usr/bin/env cosmic
-- `_work.fastimport`'s two pure halves: `diff_item`, which decides
-- which paths one item's commit must carry (no git process at all —
-- the no-op decision `_work.gitwrite` needs BEFORE it writes a
-- stream), and `build_stream`/`commit_block`, whose exact text this
-- file pins for one known item so a format regression (a missing
-- separator, a wrong byte count) is caught here rather than only as
-- a git parse failure three layers up. `run`'s actual git-writing
-- half is exercised by `_work/itemtree_test.tl`'s tree round trip and
-- by every `_work/store_test.tl`/`_work/storeref_test.tl` mutation.

local check = require("cosmic.check")
local fastimport = require("_work.fastimport")
local item = require("_work.item")

--- A minimal, valid item — every field a `diff_item` test does not
--- care about left at its zero value.
--- @param over {string: any} Fields to override
--- @return item.Item The item
local function make_item(over?: {string: any}): item.Item
  local t: {string: any} = {id = "item0001", title = "a title"}
  for k, v in pairs(over or {}) do
    t[k] = v
  end
  return check.must(item.decode(t))
end

-- A brand-new item (`old` nil) has every non-zero path "added": the
-- meta blob always, plus a beat and a blocker with its reason.
local function test_diff_item_new_item_adds_every_path()
  local it = make_item({beats = "beatee", blocked_by = "blockerid",
      block_reason = {blockerid = "why"}})
  local ops = fastimport.diff_item(nil, it, nil, "")
  local by_path: {string: string} = {}
  for _, op in ipairs(ops) do
    by_path[op.path] = op.content
  end
  assert(by_path["meta"] ~= nil, "meta is always written for a new item")
  assert(by_path["edges/beats/beatee"] == "", "a beat is an empty marker blob")
  assert(by_path["edges/blocked_by/blockerid"] == "why", "the reason rides the blob")
  assert(by_path["spec.md"] == nil, "no spec_replacement means no spec.md op")
  assert(by_path["held"] == nil, "an unheld item writes no held marker")
end

-- A held item's brand-new commit writes the `held` marker too, and
-- dropping the hold on an already-held item deletes it.
local function test_diff_item_held_marker_added_and_removed()
  local held = make_item({is_held = true})
  local new_ops = fastimport.diff_item(nil, held, nil, "")
  local added: {string: string} = {}
  for _, op in ipairs(new_ops) do
    if op.content ~= nil then
      added[op.path] = op.content
    end
  end
  assert(added["held"] == "", "a brand-new held item writes the marker")

  local unheld = make_item()
  local drop_ops = fastimport.diff_item(held, unheld, nil, "")
  local deleted = false
  for _, op in ipairs(drop_ops) do
    if op.path == "held" and op.content == nil then
      deleted = true
    end
  end
  assert(deleted, "dropping the hold deletes the marker")
end

-- An edge kind this build does not interpret — carried opaquely on
-- `other_edges` — diffs the same shape `blocked_by` does: add,
-- change, remove, one op per id that actually moved.
local function test_diff_item_other_edges_round_trips()
  local old = make_item()
  old.other_edges = {relates = {a = "why a", b = "same"}}
  local new_it = make_item()
  new_it.other_edges = {relates = {a = "why a changed", b = "same", c = ""}}
  local ops = fastimport.diff_item(old, new_it, nil, "")
  local by_path: {string: string} = {}
  local deleted: {string: boolean} = {}
  for _, op in ipairs(ops) do
    if op.content == nil then
      deleted[op.path] = true
    else
      by_path[op.path] = op.content
    end
  end
  assert(by_path["edges/relates/a"] == "why a changed", "a's reason moved")
  assert(by_path["edges/relates/b"] == nil and not deleted["edges/relates/b"],
    "b is unchanged: no op at all")
  assert(by_path["edges/relates/c"] == "", "c is a fresh add")
end

-- Nothing changed between `old` and the same item passed as `new_it`
-- (a re-take of the same state, say): the diff is empty, which is
-- exactly what `_work.gitwrite` uses to decide a no-op BEFORE ever
-- building a stream.
local function test_diff_item_unchanged_item_is_empty()
  local it = make_item({beats = "beatee", blocked_by = "blockerid",
      block_reason = {blockerid = "why"}})
  local old = check.must(item.decode(item.encode(it)))
  local ops = fastimport.diff_item(old, it, nil, "")
  assert(#ops == 0, "identical old and new items diff to nothing")
end

-- A scalar field change (claim) rewrites the WHOLE meta blob (one
-- path, never a per-field write) and touches nothing else.
local function test_diff_item_scalar_change_rewrites_meta_only()
  local old = make_item()
  local new_it = make_item({claim = "session-a"})
  local ops = fastimport.diff_item(old, new_it, nil, "")
  assert(#ops == 1, "only meta moved: " .. #ops)
  assert(ops[1].path == "meta")
  assert(ops[1].content:find("claim: session%-a", 1, false) ~= nil, ops[1].content)
end

-- A beat dropped and another added: exactly one `D` and one add, the
-- untouched paths (meta, an unrelated blocker) never appear.
local function test_diff_item_beats_add_and_remove()
  local old = make_item({beats = "gone"})
  local new_it = make_item({beats = "kept new"})
  local ops = fastimport.diff_item(old, new_it, nil, "")
  local by_path: {string: string} = {}
  local deleted: {string: boolean} = {}
  for _, op in ipairs(ops) do
    if op.content == nil then
      deleted[op.path] = true
    else
      by_path[op.path] = op.content
    end
  end
  assert(deleted["edges/beats/gone"], "the dropped beat is a D")
  assert(by_path["edges/beats/kept"] == "", "kept is a fresh add too (a different id)")
  assert(by_path["edges/beats/new"] == "", "the added beat is present")
  assert(by_path["meta"] == nil, "meta itself never moved")
end

-- A blocker's reason text changing is a REPLACE (an `M`, not a
-- delete-then-add); a blocker present in both with the SAME reason is
-- untouched.
local function test_diff_item_blocked_by_reason_change_is_one_m()
  local old = make_item({blocked_by = "b1 b2",
      block_reason = {b1 = "old reason", b2 = "same"}})
  local new_it = make_item({blocked_by = "b1 b2",
      block_reason = {b1 = "new reason", b2 = "same"}})
  local ops = fastimport.diff_item(old, new_it, nil, "")
  assert(#ops == 1, "only b1's reason moved: " .. #ops)
  assert(ops[1].path == "edges/blocked_by/b1")
  assert(ops[1].content == "new reason")
end

-- `spec_replacement` nil never touches spec.md, whatever `old_spec`
-- says (it is not even read in that case by a real caller — see
-- `_work.gitwrite.plan_one`); a replacement equal to the current text
-- is a no-op on that path, and a genuine change is an `M`; "" deletes
-- an existing sidecar rather than writing an empty blob.
local function test_diff_item_spec_replacement_rules()
  local it = make_item()
  assert(#fastimport.diff_item(it, it, nil, "anything") == 0,
    "nil spec_replacement: no op, whatever old_spec is")
  assert(#fastimport.diff_item(it, it, "same", "same") == 0,
    "an identical replacement is a no-op")
  local changed = fastimport.diff_item(it, it, "new text", "old text")
  assert(#changed == 1 and changed[1].path == "spec.md"
    and changed[1].content == "new text", "a genuine replacement is one M")
  local cleared = fastimport.diff_item(it, it, "", "had text")
  assert(#cleared == 1 and cleared[1].path == "spec.md" and cleared[1].content == nil,
    "\"\" against existing text deletes spec.md")
  assert(#fastimport.diff_item(it, it, "", "") == 0,
    "\"\" against no existing text is still a no-op")
end

-- "now" is `<epoch> <+HHMM>` — the same raw shape
-- `GIT_AUTHOR_DATE`/`_work.import`'s replayed dates already use, which
-- both `git commit-tree` and fast-import's own commit date field
-- accept without a `--date-format` flag.
local function test_git_date_now_shape()
  local d = fastimport.git_date_now()
  local epoch, sign, hh, mm = d:match("^(%d+) ([+%-])(%d%d)(%d%d)$")
  assert(epoch ~= nil, "got: " .. d)
  assert(sign == "+" or sign == "-")
  assert(tonumber(hh) < 24 and tonumber(mm) < 60, "got: " .. d)
end

-- The stream text for one KNOWN item, pinned byte for byte: a
-- `commit` line naming the ref, `author`/`committer` lines, a `data`
-- block holding the message plus its `Op:` trailer (with its own
-- trailing newline folded into the counted bytes), a `from` line
-- naming the parent, one `M 100644 inline` per written path with its
-- own `data` block, and a final `done`. A format drift here (a
-- missing separator, a byte count off by one) breaks fast-import's
-- own parse, not just this assertion, but pinning the text is what
-- makes that failure legible instead of a raw git parse error.
local function test_build_stream_for_a_known_item()
  local plan: fastimport.CommitPlan = {
    ref = "refs/items/known01", from = "aaaa000011112222333344445555666677778888",
    author_name = "session-a", author_email = "session-a@board",
    author_date = "1700000000 +0000", committer_name = "Claude",
    committer_email = "noreply@anthropic.com", committer_date = "1700000000 +0000",
    message = "take known01 by session-a", op = "take",
    ops = {
      {path = "meta", content = "title: a title\nclaim: session-a\n"},
      {path = "edges/beats/beatee", content = ""},
      {path = "edges/blocked_by/oldid", content = nil},
    },
  }
  local stream = fastimport.build_stream({plan})
  local expected = table.concat({
      "commit refs/items/known01\n",
      "author session-a <session-a@board> 1700000000 +0000\n",
      "committer Claude <noreply@anthropic.com> 1700000000 +0000\n",
      "data 36\n",
      "take known01 by session-a\n\nOp: take\n",
      "\n",
      "from aaaa000011112222333344445555666677778888\n",
      "M 100644 inline meta\n",
      "data 32\n",
      "title: a title\nclaim: session-a\n",
      "\n",
      "M 100644 inline edges/beats/beatee\n",
      "data 0\n",
      "\n",
      "D edges/blocked_by/oldid\n",
      "done\n",
    })
  assert(stream == expected, "stream text drifted:\n--- got ---\n" .. stream
    .. "\n--- want ---\n" .. expected)
end

-- No `mark` line at all when a commit's plan carries none — the
-- ordinary save path never needs one, only `_work.import`'s replayed
-- chains do.
local function test_build_stream_omits_mark_when_unset()
  local plan: fastimport.CommitPlan = {
    ref = "refs/items/x", from = nil,
    author_name = "Claude", author_email = "noreply@anthropic.com",
    author_date = "1700000000 +0000", committer_name = "Claude",
    committer_email = "noreply@anthropic.com", committer_date = "1700000000 +0000",
    message = "new x", op = "new", ops = {},
  }
  local stream = fastimport.build_stream({plan})
  assert(stream:find("\nmark ", 1, true) == nil, stream)
  assert(stream:find("\nfrom ", 1, true) == nil, "a new item has no from: " .. stream)
end
