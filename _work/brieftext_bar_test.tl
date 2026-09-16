#!/usr/bin/env cosmic
-- What every template tells an author to WRITE, pinned against the bar
-- the gate enforces. `_work.spec`'s bar asks for a Change;
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
      .. "as direction for the taker to confirm against the tree, "
      .. "plus `## Non-goals` where a wall is at stake — and NO other "
      .. "section: a write refuses one, and a repository the spec's own "
      .. "text reaches is a declared fact on the item, reported by the "
      .. "ready bar rather than written as prose)", 1, true) ~= nil,
    "a drafted capture meets the bar the gate enforces, and is told the "
    .. "bar is closed: " .. RESEARCH)
  assert(RESEARCH:find("`## Access`", 1, true) == nil,
    "and is not sent to write a section a write refuses")
  assert(RESEARCH:find(
      "No `## Goal` — goal context is the parent chain.", 1, true) ~= nil,
    "a drafted capture carries no Goal section")
  assert(RESEARCH:find("## Acceptance", 1, true) == nil,
    "and names no Acceptance section at all: nothing reads one")
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
      .. "chain.", 1, true) ~= nil,
    "the refine brief forbids a Goal section")
  assert(REFINE:find("## Acceptance", 1, true) == nil,
    "and names no Acceptance section at all: nothing reads one")
end

-- The bar dropped pasted measurement from a spec (`help bar`:
-- "Direction, not measurement"); no template may still tell a refiner
-- or a builder that a tree-fact must be measured, with its command,
-- into the prose, or ask for a pasted command's output.
local function test_no_template_asks_for_pasted_measurement()
  for _, t in ipairs({BUILDER, REWORK, RESEARCH, REFINE, DECOMPOSE,
      REVIEW_SCRIPT}) do
    assert(t:find("measured with the command", 1, true) == nil,
      "no template may ask for a tree-fact measured with its command: "
      .. t)
    assert(t:find("pasted output", 1, true) == nil,
      "no template may ask for a claim's pasted output: " .. t)
    -- `POSTURE_RESEARCH` legitimately keeps "measured claim" — a
    -- research handover's deliverable IS recorded evidence with its
    -- command — but it is not one of the templates iterated here, so
    -- this catches the narrower phrase without touching that doctrine.
    assert(t:find("measured fact", 1, true) == nil,
      "no template may ask a reviewer or builder to verify a spec-named "
      .. "fact as measured: " .. t)
  end
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
  -- No spec blob carries the heading, so no template reads one.
  for _, t in ipairs({BUILDER, REWORK, RESEARCH, REFINE, DECOMPOSE,
      REVIEW, REVIEW_SCRIPT}) do
    assert(t:find("## Acceptance", 1, true) == nil,
      "no template may name an Acceptance section: " .. t)
  end
end
