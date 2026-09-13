#!/usr/bin/env cosmic
-- The spec bar's grammar: the one heading a spec must carry, what
-- counts as carrying it, and that everything else rides along
-- unjudged. A heading with nothing under it is a gap, because a
-- pasted template is the failure mode this exists to catch. There is
-- no Acceptance section to lint: the CI gate is the one acceptance,
-- so the bar has nothing to say about how an item proves itself.
local check = require("cosmic.check")
local child = require("cosmic.child")
local spec = require("_work.spec")

--- A minimal bar-complete body for tests. Non-goals is optional
--- prose: it rides along and the bar has nothing to say about it.
local READY_BODY < const > = [[
## Change
Add the verb.

## Non-goals
No contract changes.
]]

-- Migration adequacy stays a caller judgment, not a filename/keyword grammar.
local function test_tracking_file_mentions_do_not_add_a_machine_migration_grammar()
  for _, change in ipairs({
      "Change docs/design/cast-sites.tsv from 3 columns to 5.",
      "Change docs/design/cast-sites.tsv from 3 columns to 5. "
      .. "Migrate existing rows with a committed rewrite.",
      "Correct one row in docs/design/cast-sites.tsv without changing its shape.",
      "Add one entry to _work/example_baseline.tl.",
    }) do
    local gaps = spec.ready_gaps("## Change\n" .. change .. "\n")
    assert(#gaps == 0, "syntax-only bar must preserve this body: " .. change
      .. "; got " .. table.concat(gaps, ", "))
  end
end

local function test_ready_gaps_complete()
  local gaps = spec.ready_gaps(READY_BODY)
  assert(#gaps == 0, "unexpected gaps: " .. table.concat(gaps, ", "))
end

local function test_change_alone_suffices()
  local gaps = spec.ready_gaps("## Change\nAdd it.\n")
  assert(#gaps == 0,
    "Change is the whole bar: " .. table.concat(gaps, ", "))
end

local function test_ready_gaps_missing()
  local gaps = spec.ready_gaps("## Goal\nserve G8\n")
  assert(#gaps == 1, "expected 1 gap, got " .. tostring(#gaps))
  assert(gaps[1] == "Change is missing or empty",
    "got: " .. tostring(gaps[1]))
end

local function test_ready_gaps_case_and_level()
  local gaps = spec.ready_gaps("### CHANGE\nx\n")
  assert(#gaps == 0, "case/level should not matter: " .. table.concat(gaps, ", "))
end

-- A heading closes the open section only at its own level or
-- shallower, so a `###` subheading inside `## Change` is content: its
-- own line and the lines under it belong to Change, and it opens no
-- section of its own. A path a spec names under such a subheading is
-- therefore part of the Change every reader of the section sees.
local function test_a_subheading_is_content_of_the_section_above_it()
  local body = table.concat({
      "## Change", "", "Rework the scanner.", "",
      "### `_work/spec.tl`", "", "Record each section's heading level.", "",
      "## Non-goals", "", "A fence-aware scanner.",
    }, "\n")
  local found = spec.sections(body)
  local change = found["change"] or ""
  assert(change:find("_work/spec.tl", 1, true) ~= nil,
    "the subheading's own backticked path belongs to Change: " .. change)
  assert(change:find("heading level", 1, true) ~= nil,
    "and so do the lines under it: " .. change)
  assert(found["`_work/spec.tl`"] == nil,
    "no section is keyed by the subheading's text")
end

-- A sidecar is `##`-sectioned, so a lone `#` is its TITLE, not a
-- container: `## Change` under `# Item title` is the Change section,
-- not prose inside the title. Without this floor the level rule above
-- reads a titled sidecar as carrying no Change at all, which refuses
-- a pull outright — a worse failure than the missed path it fixes.
local function test_a_level_one_title_does_not_contain_the_sections()
  local body = table.concat({
      "# Friction: 2026-09-06 work9", "",
      "## Change", "", "Edit `_work/spec.tl`.", "",
      "## Non-goals", "", "Nothing else.",
    }, "\n")
  local found = spec.sections(body)
  local change = found["change"] or ""
  assert(change:find("_work/spec.tl", 1, true) ~= nil,
    "Change under a title is the Change section: " .. change)
  assert(found["non-goals"] == "Nothing else.\n",
    "got: " .. tostring(found["non-goals"]))
  local gaps = spec.ready_gaps(body)
  assert(#gaps == 0, "a titled sidecar still meets the bar: "
    .. table.concat(gaps, ", "))
end

-- The floor makes a level-1 heading a non-container, never unreadable:
-- a spec that writes its Change with a single `#` is still read, the
-- way this module's grammar has always counted a heading at any level.
local function test_a_level_one_heading_still_opens_a_section()
  for _, body in ipairs({"# Change\nAdd it.\n", "# change\nAdd it.\n"}) do
    local gaps = spec.ready_gaps(body)
    assert(#gaps == 0, "a level-1 Change is a Change: " .. body .. " -> "
      .. table.concat(gaps, ", "))
  end
end

-- Two sibling headings at the same level still separate: the level
-- rule closes a section on an equal heading, not only a shallower one.
local function test_sibling_sections_at_one_level_still_separate()
  local found = spec.sections(
    "## Change\nEdit it.\n## Non-goals\nNothing else.\n")
  assert(found["change"] == "Edit it.\n", "got: " .. tostring(found["change"]))
  assert(found["non-goals"] == "Nothing else.\n",
    "got: " .. tostring(found["non-goals"]))
end

local function test_ready_gaps_footer_is_not_content()
  local gaps = spec.ready_gaps("## Change\n\n---\n_Generated by a footer_\n")
  assert(#gaps == 1 and gaps[1] == "Change is missing or empty",
    "footer below --- should not fill a section: " .. table.concat(gaps, ", "))
end

local function test_ready_gaps_empty_section_counts()
  local gaps = spec.ready_gaps("## Change\n\n## Acceptance\n`x`\n")
  assert(#gaps == 1, "expected 1 gap, got " .. table.concat(gaps, ", "))
  assert(gaps[1] == "Change is missing or empty",
    "hollow heading should count as a gap")
end

-- An Acceptance section a legacy sidecar still carries is ordinary
-- optional prose: never required, never judged.
local function test_acceptance_is_not_judged()
  local gaps = spec.ready_gaps(
    "## Change\nAdd the verb.\n## Acceptance\nworks correctly and is fast\n")
  assert(#gaps == 0,
    "a ride-along Acceptance is not the bar's business: "
    .. table.concat(gaps, ", "))
end

-- A sweep-shaped Change (`--apply`) with no pasted dry-run evidence
-- anywhere in the spec is refused, naming the missing paste.
local function test_sweep_apply_without_pasted_evidence_is_a_gap()
  local gaps = spec.ready_gaps(
    "## Change\nRun `--rewrite '$F:^test_()' '' --apply` over 12 files.\n")
  assert(#gaps == 1, "expected 1 gap, got " .. table.concat(gaps, ", "))
  assert(gaps[1]:find("no pasted dry-run", 1, true) ~= nil,
    "gap should name the missing paste: " .. gaps[1])
end

-- The same, for `--fix` rather than `--apply` — the sentence covers
-- any sweep tool, not only cosmic's own --rewrite.
local function test_sweep_fix_without_pasted_evidence_is_a_gap()
  local gaps = spec.ready_gaps("## Change\nRun `eslint --fix` over the tree.\n")
  assert(#gaps == 1, "expected 1 gap, got " .. table.concat(gaps, ", "))
  assert(gaps[1]:find("no pasted dry-run", 1, true) ~= nil,
    "gap should name the missing paste: " .. gaps[1])
end

-- A pasted `applied`/`refused` line, fenced anywhere in the spec,
-- clears the gap — it need not sit inside `## Change` itself.
local function test_sweep_apply_with_pasted_applied_line_is_ready()
  local body = [[
## Change
Run `--rewrite '$F:^test_()' '' --apply` over 12 files.

## Evidence
Dry run: `rewrite: 12 applied, 0 refused in 12 file(s)`
]]
  local gaps = spec.ready_gaps(body)
  assert(#gaps == 0, "pasted applied line should clear the gap: "
    .. table.concat(gaps, ", "))
end

-- A pasted refusal is evidence too — the sweep ran and refused, which
-- is still the command's own output, not only its --find count.
local function test_sweep_apply_with_pasted_refusal_is_ready()
  local body = [[
## Change
Run `--rewrite '$F:^test_()' '' --apply` over 12 files.

## Evidence
`rewrite: refused: testdata/ excluded by the project model`
]]
  local gaps = spec.ready_gaps(body)
  assert(#gaps == 0, "a pasted refusal should clear the gap: "
    .. table.concat(gaps, ", "))
end

-- Prose that merely mentions "applied" outside a code span is not a
-- paste of the command's own output.
local function test_sweep_apply_with_prose_mention_still_gaps()
  local body = "## Change\nRun `--apply` once applied it should show 0.\n"
  local gaps = spec.ready_gaps(body)
  assert(#gaps == 1, "an unfenced mention of \"applied\" is not evidence: "
    .. table.concat(gaps, ", "))
end

-- A Change with no sweep flag at all is unaffected — the gap only
-- fires when the Change itself names --apply or --fix.
local function test_non_sweep_change_has_no_sweep_gap()
  local gaps = spec.ready_gaps("## Change\nAdd the verb.\n")
  assert(#gaps == 0, "a non-sweep Change should not gap: "
    .. table.concat(gaps, ", "))
end

-- A word like `--fixture` is not the `--fix` flag; the frontier check
-- must not false-positive on it.
local function test_sweep_word_boundary_on_fix()
  local gaps = spec.ready_gaps("## Change\nAdd a new --fixture flag.\n")
  assert(#gaps == 0, "--fixture is not --fix: " .. table.concat(gaps, ", "))
end

-- A revision is the git blob sha `spec.md` itself would carry: same
-- text, same revision; any edit, a different one; and no sidecar at
-- all is a stable constant.
local function test_revision_is_a_content_digest()
  local a = spec.revision(READY_BODY)
  assert(a == spec.revision(READY_BODY), "two readings agree")
  assert(#a == 40 and a:match("^[0-9a-f]+$"), "40 hex characters: " .. a)
  assert(a ~= spec.revision(READY_BODY .. "moved\n"), "any edit moves it")
  assert(spec.revision("") == spec.revision(""), "no sidecar is stable")
end

-- The revision is not just A digest, it is the SAME sha
-- `git hash-object` gives that exact blob — `_work.store` writes
-- `spec.md` through `git hash-object -w --stdin`, so a caller
-- comparing against `spec.revision` has to be comparing against what
-- is actually in the tree.
local function test_revision_matches_git_hash_object()
  local body = READY_BODY
  local r = child.run({"git", "hash-object", "--stdin"}, {stdin = body})
  if r == nil or not r.ok then
    -- No git on PATH in this environment: skip rather than fail a
    -- test of git's own behavior on a machine that lacks git.
    return
  end
  assert(spec.revision(body) == (r.stdout:gsub("%s+$", "")),
    "spec.revision agrees with git hash-object: " .. spec.revision(body)
    .. " vs " .. r.stdout)
end

-- `reached_repos` reads a `github.com` URL wherever it sits, HTTPS or
-- SSH, deduplicated regardless of which section carries it.
local function test_reached_repos_finds_github_urls_anywhere()
  local body = [[
## Change
git clone https://github.com/jart/cosmopolitan /tmp/upstream

## Evidence
git@github.com:jart/cosmopolitan.git also names it, again.
]]
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

-- `declared_repos` reads only the `## Access` section, by URL or by a
-- bare `owner/repo` mention — cheap because the section exists to be
-- written once and read, not parsed strictly.
local function test_declared_repos_reads_only_access()
  local body = [[
## Change
See jart/cosmopolitan for prior art.

## Access
- jart/cosmopolitan (read-only, upstream history)
]]
  local declared = spec.declared_repos(body)
  assert(declared["jart/cosmopolitan"], "declared under Access")
  local undeclared = spec.declared_repos("## Change\njart/cosmopolitan\n")
  assert(not undeclared["jart/cosmopolitan"],
    "a mention outside Access is not a declaration")
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
