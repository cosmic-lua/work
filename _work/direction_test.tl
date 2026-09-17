#!/usr/bin/env cosmic
local direction = require("_work.direction")
local spec = require("_work.spec")
local check = require("cosmic.check")

local function test_both_families_and_word_boundaries()
  for _, phrase in ipairs({"every spawned agent", "all callers",
      "all the callers", "each template", "every template", "all templates",
      "already knows", "already records", "already recorded", "the caller has it"}) do
    local hints = direction.hints({change = phrase:upper():gsub(" ", "\n\t")})
    assert(#hints == 1, "each bounded phrase warns: " .. phrase)
    assert(hints[1]:find('"' .. phrase .. '"', 1, true) ~= nil)
    assert(hints[1]:find("no recognized direction anchor", 1, true) ~= nil)
    assert(hints[1]:find("where should the builder look", 1, true) ~= nil)
    assert(hints[1]:find("advisory", 1, true) ~= nil)
    assert(#direction.hints({change = "x" .. phrase .. "z"}) == 0)
  end
  assert(#direction.hints({change = "every changed line; all things; each one"}) == 0)
  assert(#direction.hints(nil) == 0)
  assert(#direction.hints({}) == 0)
end

local function test_deduplication_is_per_family()
  local hints = direction.hints({change = "All callers and every template: "
      .. "the caller has it and already knows and already recorded."})
  assert(#hints == 2, "one hint per family")
end

local function test_anchors_anywhere_in_change()
  for _, anchor in ipairs({"src/worker.tl", "worker.tl", "`worker`",
      "`_work/templates/`", "`src/worker.tl`",
      "`item.claim`", "`item:claim`", "item.claim", "claim_base",
      "set Workers: alpha, beta", "list Templates:\n- alpha\n- beta"}) do
    for _, gap in ipairs({" ", "\n\n"}) do
      assert(#direction.hints({change = "All callers already know; "
            .. "the caller has it." .. gap .. anchor}) == 0,
        "whole-Change anchor suppresses both families: " .. anchor)
    end
  end
end

local function test_examples_are_neither_phrases_nor_anchors()
  for _, wrap in ipairs({"```lua\n%s\n```", "~~~~\n%s\n~~~~",
      "> %s", '"%s"', "'%s'", "`%s`"}) do
    assert(#direction.hints({change = wrap:format("all callers already knows")}) == 0,
      "examples do not warn: " .. wrap)
  end
  for _, wrap in ipairs({"```\n%s\n```", "~~~\n%s\n~~~", "> %s", '"%s"', "'%s'"}) do
    assert(#direction.hints({change = "all callers already knows\n"
          .. wrap:format("src/work.tl `field` item.claim claim_base set Workers: a")}) == 2,
      "example anchors cannot suppress warnings: " .. wrap)
  end
  assert(#direction.hints({change = "The builder's plan updates all callers."}) == 1)
  assert(#direction.hints({change = "```\nall callers\n``\nalready knows"}) == 0)
  local prose = check.must(spec.split("## Change\nEvery changed line.\n"
      .. "## Non-goals\nall callers already knows\n"))
  assert(#direction.hints(prose) == 0, "only Change is scanned")
  assert(#direction.hints({change = "all callers", non_goals = "src/work.tl"}) == 1)
end

local function test_unquoted_anchor_shapes()
  local claim = "All callers already know; the caller has it. "
  for _, plain in ipairs({"and/or", "new/show", "cosmic-lua/work", "e.g.", "i.e.", "a_b"}) do
    assert(#direction.hints({change = claim .. plain}) == 2, "does not anchor: " .. plain)
  end
  for _, anchor in ipairs({"_work/x.tl", "docs/guide.md", "spec.ready_gaps",
      "ready_gaps", "`verb`"}) do
    assert(#direction.hints({change = claim .. anchor}) == 0, "anchors: " .. anchor)
  end
end

-- Whole Change examples chosen for their meaning, not harvested from hints.
-- PR211's token-level slash/abbreviation regressions above stay intact; these
-- pair realistic unanchored prose with pointers and quoted counterexamples.
local record DirectionCase
  label: string
  change: string
  phrases: {string}
end

local function test_independent_change_decision_corpus()
  local cases: {DirectionCase} = {
    {label = "ordinary slash prose cannot supply direction",
      change = "Update all callers to show read/write status and pass/fail results. "
      .. "The caller has it after review.", phrases = {"all callers", "the caller has it"}},
    {label = "abbreviations cannot supply direction",
      change = "Each template must show the same status, e.g. pending, i.e. not finished. "
      .. "The caller already records the result.", phrases = {"each template", "already records"}},
    {label = "actual scanner source pointer",
      change = "Update all callers of the scanner in _work/direction.tl. "
      .. "The caller already knows the result.", phrases = {}},
    {label = "actual doctrine pointer across paragraphs",
      change = "Every template must carry the same direction.\n\n"
      .. "Use _work/doctrine_bar.tl for the wording.", phrases = {}},
    {label = "explicit set names the reach",
      change = "Update all templates. Set Templates: builder, reviewer.", phrases = {}},
    {label = "quoted source is only an example",
      change = 'Update every template; the caller has it. The example says '
      .. '"inspect _work/direction.tl".', phrases = {"every template", "the caller has it"}},
    {label = "blockquoted source is only an example",
      change = "All callers must expose the status.\n> Inspect _work/spec.tl.\n"
      .. "The caller already recorded the decision.", phrases = {"all callers", "already recorded"}},
    {label = "fenced pointer cannot hide following instruction",
      change = "Example:\n~~~~tl\n_work/direction.tl\n~~~~\n"
      .. "Update every spawned agent; the caller has it.",
      phrases = {"every spawned agent", "the caller has it"}},
    {label = "quoted family does not add a second hint",
      change = 'Update all callers. Replace the words "the caller has it" in the example.',
      phrases = {"all callers"}},
    {label = "inline example does not become an instruction",
      change = "Explain why `all callers already knows` is vague.", phrases = {}},
    {label = "ordinary change outside bounded phrase policy",
      change = "Show a helpful status for each operation and preserve the current output.", phrases = {}},
  }
  for _, case in ipairs(cases) do
    local parsed = check.must(spec.split("## Change\n" .. case.change .. "\n"))
    local hints = direction.hints(parsed)
    assert(#hints == #case.phrases, "independent direction decision: " .. case.label)
    for i, phrase in ipairs(case.phrases) do
      assert(hints[i]:find('"' .. phrase .. '"', 1, true) ~= nil,
        "independent direction phrase: " .. case.label .. ": " .. phrase)
    end
  end
end
