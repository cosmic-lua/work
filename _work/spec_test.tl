#!/usr/bin/env cosmic
-- The spec bar's grammar over the two blobs an item's `spec/` subtree
-- holds: a Change with something in it, and a sweep-shaped Change
-- with its own dry-run paste. Non-goals rides along unjudged. There
-- is no heading to scan and no Acceptance section to lint: the blob
-- IS the section, and the CI gate is the one acceptance, so the bar
-- has nothing to say about how an item proves itself. `document` and
-- `split`, the two directions between the blobs and the one markdown
-- file an author edits, are pinned below.
local check = require("cosmic.check")
local itemtree = require("_work.itemtree")
local spec = require("_work.spec")

--- A minimal bar-complete record for tests. Non-goals is optional
--- prose: it rides along and the bar has nothing to say about it.
local READY < const >: itemtree.Spec = {
  change = "Add the verb.\n",
  non_goals = "No contract changes.\n",
}

--- A record whose Change is `change` and whose Non-goals is empty.
--- @param change string The Change blob
--- @return itemtree.Spec
local function with_change(change: string): itemtree.Spec
  return {change = change, non_goals = ""}
end

-- Migration adequacy stays a caller judgment, not a filename/keyword grammar.
local function test_tracking_file_mentions_do_not_add_a_machine_migration_grammar()
  for _, change in ipairs({
      "Change docs/design/cast-sites.tsv from 3 columns to 5.",
      "Change docs/design/cast-sites.tsv from 3 columns to 5. "
      .. "Migrate existing rows with a committed rewrite.",
      "Correct one row in docs/design/cast-sites.tsv without changing its shape.",
      "Add one entry to _work/example_baseline.tl.",
    }) do
    local gaps = spec.ready_gaps(with_change(change .. "\n"))
    assert(#gaps == 0, "syntax-only bar must preserve this body: " .. change
      .. "; got " .. table.concat(gaps, ", "))
  end
end

local function test_ready_gaps_complete()
  local gaps = spec.ready_gaps(READY)
  assert(#gaps == 0, "unexpected gaps: " .. table.concat(gaps, ", "))
end

local function test_change_alone_suffices()
  local gaps = spec.ready_gaps(with_change("Add it.\n"))
  assert(#gaps == 0,
    "Change is the whole bar: " .. table.concat(gaps, ", "))
end

-- A record with no Change misses the bar whatever its Non-goals say,
-- and so does no record at all — an item that has never had a spec.
local function test_ready_gaps_missing()
  local gaps = spec.ready_gaps({change = "", non_goals = "serve G8\n"})
  assert(#gaps == 1, "expected 1 gap, got " .. tostring(#gaps))
  assert(gaps[1] == "Change is missing or empty",
    "got: " .. tostring(gaps[1]))
  local none = spec.ready_gaps(nil)
  assert(#none == 1 and none[1] == "Change is missing or empty",
    "no prose at all: " .. table.concat(none, ", "))
end

-- A Change of nothing but whitespace is hollow — the pasted template
-- with an empty section is the failure mode the bar exists to catch.
local function test_ready_gaps_blank_change_counts()
  local gaps = spec.ready_gaps(with_change("  \n\n\t\n"))
  assert(#gaps == 1 and gaps[1] == "Change is missing or empty",
    "a blank Change is a gap: " .. table.concat(gaps, ", "))
end

-- A sweep-shaped Change (`--apply`) with no pasted dry-run evidence
-- in either blob is refused, naming the missing paste.
local function test_sweep_apply_without_pasted_evidence_is_a_gap()
  local gaps = spec.ready_gaps(
    with_change("Run `--rewrite '$F:^test_()' '' --apply` over 12 files.\n"))
  assert(#gaps == 1, "expected 1 gap, got " .. table.concat(gaps, ", "))
  assert(gaps[1]:find("no pasted dry-run", 1, true) ~= nil,
    "gap should name the missing paste: " .. gaps[1])
end

-- The same, for `--fix` rather than `--apply` — the sentence covers
-- any sweep tool, not only cosmic's own --rewrite.
local function test_sweep_fix_without_pasted_evidence_is_a_gap()
  local gaps = spec.ready_gaps(with_change("Run `eslint --fix` over the tree.\n"))
  assert(#gaps == 1, "expected 1 gap, got " .. table.concat(gaps, ", "))
  assert(gaps[1]:find("no pasted dry-run", 1, true) ~= nil,
    "gap should name the missing paste: " .. gaps[1])
end

-- A pasted `applied` line, fenced in the Change itself, clears the gap.
local function test_sweep_apply_with_pasted_applied_line_is_ready()
  local gaps = spec.ready_gaps(with_change(table.concat({
          "Run `--rewrite '$F:^test_()' '' --apply` over 12 files.", "",
          "Dry run: `rewrite: 12 applied, 0 refused in 12 file(s)`", "",
        }, "\n")))
  assert(#gaps == 0, "pasted applied line should clear the gap: "
    .. table.concat(gaps, ", "))
end

-- The paste may sit in the OTHER blob: both are read for it, only the
-- Change is read for the flag.
local function test_sweep_paste_in_non_goals_is_ready()
  local gaps = spec.ready_gaps({
      change = "Run `--rewrite '$F:^test_()' '' --apply` over 12 files.\n",
      non_goals = "No second pass: `rewrite: 12 applied, 0 refused in 12 "
      .. "file(s)` is the whole sweep.\n",
    })
  assert(#gaps == 0, "a paste in Non-goals clears the gap: "
    .. table.concat(gaps, ", "))
end

-- A `--apply` that appears only in Non-goals is a wall, not a sweep:
-- the flag is read from the Change alone.
local function test_sweep_flag_in_non_goals_is_not_a_sweep()
  local gaps = spec.ready_gaps({
      change = "Add the verb.\n",
      non_goals = "No `--apply` pass over the tree.\n",
    })
  assert(#gaps == 0, "a wall naming --apply is not a sweep: "
    .. table.concat(gaps, ", "))
end

-- A pasted refusal is evidence too — the sweep ran and refused, which
-- is still the command's own output, not only its --find count.
local function test_sweep_apply_with_pasted_refusal_is_ready()
  local gaps = spec.ready_gaps(with_change(table.concat({
          "Run `--rewrite '$F:^test_()' '' --apply` over 12 files.", "",
          "`rewrite: refused: testdata/ excluded by the project model`", "",
        }, "\n")))
  assert(#gaps == 0, "a pasted refusal should clear the gap: "
    .. table.concat(gaps, ", "))
end

-- Prose that merely mentions "applied" outside a code span is not a
-- paste of the command's own output.
local function test_sweep_apply_with_prose_mention_still_gaps()
  local gaps = spec.ready_gaps(
    with_change("Run `--apply` once applied it should show 0.\n"))
  assert(#gaps == 1, "an unfenced mention of \"applied\" is not evidence: "
    .. table.concat(gaps, ", "))
end

-- A Change with no sweep flag at all is unaffected — the gap only
-- fires when the Change itself names --apply or --fix.
local function test_non_sweep_change_has_no_sweep_gap()
  local gaps = spec.ready_gaps(with_change("Add the verb.\n"))
  assert(#gaps == 0, "a non-sweep Change should not gap: "
    .. table.concat(gaps, ", "))
end

-- A word like `--fixture` is not the `--fix` flag; the frontier check
-- must not false-positive on it.
local function test_sweep_word_boundary_on_fix()
  local gaps = spec.ready_gaps(with_change("Add a new --fixture flag.\n"))
  assert(#gaps == 0, "--fixture is not --fix: " .. table.concat(gaps, ", "))
end

-- `reached_repos` reads a `github.com` URL wherever it sits in the
-- rendered document, HTTPS or SSH, deduplicated across both blobs.
local function test_reached_repos_finds_github_urls_anywhere()
  local body = spec.document({
      change = "git clone https://github.com/jart/cosmopolitan /tmp/upstream\n",
      non_goals = "git@github.com:jart/cosmopolitan.git also names it, again.\n",
    })
  local repos = spec.reached_repos(body)
  assert(#repos == 1 and repos[1] == "jart/cosmopolitan",
    "expected one dedup'd slug, got: " .. table.concat(repos, ", "))
end

-- A bare `owner/repo`-shaped mention is not a URL, so it is not a
-- reach — the module and doc paths this repo is full of would
-- otherwise false-positive on nearly every spec.
local function test_reached_repos_ignores_bare_paths()
  local repos = spec.reached_repos(
    "## Change\nEdit `cosmic/fs` per `docs/decisions`.\n")
  assert(#repos == 0, "bare paths are not repos: " .. table.concat(repos, ", "))
end

-- `document` and `split` are inverses on conforming input: a canonical
-- record round-trips through the text byte for byte, and any
-- conforming text normalizes to that canonical form.
local function test_document_and_split_are_inverses()
  local sp = {change = "Add the verb.\n", non_goals = "No contract changes.\n"}
  local rendered = spec.document(sp)
  assert(rendered == "## Change\n\nAdd the verb.\n\n"
    .. "## Non-goals\n\nNo contract changes.\n", rendered)
  local back = check.must(spec.split(rendered))
  assert(back.change == sp.change and back.non_goals == sp.non_goals,
    ("round trip moved: %q / %q"):format(back.change, back.non_goals))
  -- Non-canonical spacing and heading case normalize rather than
  -- reporting a difference, which is why `spec ID FILE` compares
  -- records and never text.
  local loose = check.must(spec.split("#  change\n\n\nAdd the verb.\n\n\n"
      .. "###### NON-GOALS\nNo contract changes."))
  assert(loose.change == sp.change and loose.non_goals == sp.non_goals,
    ("loose input did not normalize: %q / %q"):format(loose.change,
      loose.non_goals))
end

-- An empty record renders to "", which is what every caller that asks
-- "does this item have a spec at all" tests against.
local function test_document_of_no_prose_is_empty()
  assert(spec.document({change = "", non_goals = ""}) == "")
  assert(spec.document({change = "", non_goals = "Only walls.\n"})
    == "## Non-goals\n\nOnly walls.\n")
  local empty = check.must(spec.split(""))
  assert(empty.change == "" and empty.non_goals == "")
end

-- A deeper heading inside a section is content, so a Change with
-- `###` subsections keeps all of it — and a thematic break ends
-- nothing, unlike `sections`.
local function test_split_keeps_subsections_and_thematic_breaks()
  local sp = check.must(spec.split([[
## Change
Do it.

### Files
| a | b |
| --- | --- |
| 1 | 2 |

## Non-goals
Nothing else.
]]))
  assert(sp.change:find("### Files", 1, true) ~= nil, sp.change)
  assert(sp.change:find("| --- | --- |", 1, true) ~= nil, sp.change)
  assert(sp.non_goals == "Nothing else.\n", sp.non_goals)
end

-- A heading inside a fence is content: a spec that pastes a command's
-- own output quoting `## Change` is ordinary prose, not a section.
local function test_split_is_fence_aware()
  local sp = check.must(spec.split([[
## Change
Do it.

```
$ grep -c '^## Change' /tmp/specs
## Evidence
1046
```
]]))
  assert(sp.change:find("## Evidence", 1, true) ~= nil,
    "a fenced heading is content: " .. sp.change)
  assert(sp.non_goals == "", sp.non_goals)
end

-- A retired section carrying content is refused rather than dropped,
-- and the refusal names where the fact now lives AND the verb that puts
-- it there, so the refusal is also the repair. A hollow leftover
-- heading loses no fact and is dropped.
local function test_split_refuses_a_retired_section_that_carries_content()
  local sp, err = spec.split("## Change\nDo it.\n\n## Access\n- a/b\n")
  assert(sp == nil and err == "access is a declared field now, not a spec "
    .. "section: gitboard set ID --access OWNER/NAME", tostring(err))
  local _ready, rerr = spec.split("## Change\nDo it.\n\n## Ready when\nx is done\n")
  assert(_ready == nil
    and rerr == "a precondition is a dependency, not a section: "
    .. "gitboard depend ID ON ID", rerr)
  local _ev, everr = spec.split("## Change\nDo it.\n\n## Evidence\n1046 items\n")
  assert(_ev == nil and everr:find("Evidence is not a spec section", 1, true) ~= nil
    and everr:find("gitboard log ID --add FILE", 1, true) ~= nil, everr)
  local hollow = check.must(spec.split("## Change\nDo it.\n\n## Evidence\n\n"))
  assert(hollow.change == "Do it.\n", hollow.change)
end

-- Non-blank text ahead of the first heading is refused too: a
-- preamble is a narrative, and a narrative is a log entry.
local function test_split_refuses_a_preamble()
  local sp, err = spec.split("Some framing.\n\n## Change\nDo it.\n")
  assert(sp == nil and err:find("before the first heading", 1, true) ~= nil, tostring(err))
  assert(check.must(spec.split("\n\n## Change\nDo it.\n")).change == "Do it.\n")
end

-- `new` reads a caller's backticked paths back the same form a
-- `--touches` flag would have declared, once each, first-seen.
local function test_touches_from_change_reads_backticked_tl_paths()
  local paths = spec.touches_from_change(
    "Edit `_work/brief.tl` and `_work/spec.tl`, again `_work/brief.tl`.")
  assert(#paths == 2 and paths[1] == "_work/brief.tl"
    and paths[2] == "_work/spec.tl",
    "expected the two paths, deduped: " .. table.concat(paths, ", "))
end

-- A span with whitespace is a sentence or a rendered `touches: a.tl
-- b.tl` line, not one path, and does not round-trip into a derived
-- list; a non-`.tl` span and a line-numbered citation are prose too.
local function test_touches_from_change_ignores_prose_spans()
  local paths = spec.touches_from_change(
    "See `touches: _work/a.tl _work/b.tl`, `docs/goals.md`, "
    .. "and `_work/briefmeasure_test.tl:76-78` for why.")
  assert(#paths == 0, "expected nothing derived: " .. table.concat(paths, ", "))
end

-- No Change at all derives nothing — an item filed with no prose
-- still files, and an empty declared list is the same "none" the
-- rendering already treats it as.
local function test_touches_from_change_of_empty_change_is_empty()
  local paths = spec.touches_from_change("")
  assert(#paths == 0, "expected nothing derived: " .. table.concat(paths, ", "))
end
