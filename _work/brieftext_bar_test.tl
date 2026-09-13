#!/usr/bin/env cosmic
-- What every template tells an author to WRITE, pinned against the bar
-- the gate enforces. `_work.spec`'s `READY_SECTIONS` admits `## Change`;
-- `## Non-goals` carries a wall and `## Access` the repositories a spec
-- reaches beyond its item's own. A template naming `## Goal`,
-- `## Acceptance` or `## Enablement` mints a section no reader honors,
-- so each is pinned absent here. Sentences are matched against a
-- whitespace-flattened copy, as in `_work.brieftext_test`, so a rewrap
-- does not break them.

local brieftext = require("_work.brieftext")
local brieftext_review = require("_work.brieftext_review")

--- `s` with every run of whitespace collapsed to one space.
--- @param s string The text to flatten
--- @return string The flattened text
local function flat(s: string): string
  return (s:gsub("%s+", " "))
end

local BUILDER < const > = flat(brieftext.BUILDER)
local REWORK < const > = flat(brieftext.REWORK)
local RESEARCH < const > = flat(brieftext.RESEARCH)
local REFINE < const > = flat(brieftext.REFINE)
local DECOMPOSE < const > = flat(brieftext.DECOMPOSE)
local REVIEW < const > = flat(brieftext_review.REVIEW)
local REVIEW_SCRIPT < const > = flat(brieftext_review.REVIEW_SCRIPT)

local function test_research_drafts_a_capture_to_the_gates_own_bar()
  -- `## Access` left this list when `spec.split` started refusing the
  -- section: access is a declared fact on the item now, so a brief that
  -- still taught the section would teach a write the tool rejects. The
  -- claim is STRONGER than the one it replaces — the bar is named AND
  -- closed, where before it was only named.
  assert(RESEARCH:find(
      "meeting the ready bar (`## Change`, every tree-fact it names "
      .. "measured with the command that produced it, plus "
      .. "`## Non-goals` where a wall is at stake — and NO other "
      .. "section: a write refuses one, and a repository the spec's own "
      .. "text reaches is a declared fact on the item, reported by the "
      .. "ready bar rather than written as prose)", 1, true) ~= nil,
    "a drafted capture meets the bar the gate enforces, and is told the "
    .. "bar is closed: " .. RESEARCH)
  assert(RESEARCH:find("`## Access`", 1, true) == nil,
    "and is not sent to write a section a write refuses")
  assert(RESEARCH:find(
      "No `## Goal` — goal context is the parent chain — and no "
      .. "`## Acceptance`: the repo's own gate passing is the one "
      .. "definition of done every item shares, and a bound worth "
      .. "keeping permanently is a test in the diff.", 1, true) ~= nil,
    "a drafted capture carries no Goal and no Acceptance section")
  assert(RESEARCH:find("`## Acceptance` names", 1, true) == nil,
    "this item's own spec update is not pointed at an Acceptance section")
end

local function test_refine_names_the_whole_bar_and_no_retired_section()
  assert(REFINE:find(
      "Rewrite the item's `## Change` (and `## Non-goals` if a wall "
      .. "is at stake — those two and nothing else; a write refuses "
      .. "any other section, and a repository the spec reaches is a "
      .. "declared fact on the item, not prose)", 1, true) ~= nil,
    "the refine brief names the two headings the bar admits and closes "
    .. "the list: " .. REFINE)
  assert(REFINE:find("`## Access`", 1, true) == nil,
    "and does not send a refiner to write a section a write refuses")
  assert(REFINE:find(
      "Do NOT write a `## Goal` section — goal context is the parent "
      .. "chain — and do NOT write an `## Acceptance` checklist a "
      .. "builder must reproduce.", 1, true) ~= nil,
    "the refine brief forbids a Goal section and an Acceptance "
    .. "checklist both")
end

local function test_no_template_teaches_a_goal_or_enablement_section()
  for _, t in ipairs({BUILDER, REWORK, DECOMPOSE, REVIEW, REVIEW_SCRIPT}) do
    assert(t:find("## Goal", 1, true) == nil,
      "no template may name a Goal section: " .. t)
  end
  for _, t in ipairs({BUILDER, REWORK, RESEARCH, REFINE, DECOMPOSE,
      REVIEW, REVIEW_SCRIPT}) do
    assert(t:find("## Enablement", 1, true) == nil,
      "no template may name an Enablement section: " .. t)
  end
  assert(DECOMPOSE:find("## Acceptance", 1, true) == nil,
    "the decompose brief must not name an Acceptance section")
end

-- The one place the section survives: read as worked proof, never
-- re-executed as a second gate.
local function test_builder_reads_a_legacy_acceptance_without_rerunning_it()
  assert(BUILDER:find(
      "If the spec carries an `## Acceptance` section: it is the "
      .. "refiner's own worked proof, not a second gate you owe "
      .. "beyond the Change and a green gate. Never treat it as a "
      .. "checklist to reproduce, and never paste its command output "
      .. "into the PR body.", 1, true) ~= nil,
    "a legacy Acceptance section is worked proof, never a checklist")
end
