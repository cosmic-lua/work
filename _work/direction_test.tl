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
