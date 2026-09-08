--- What each kind of next action MEANS: the two or three facts a
--- session needs to act on what `next` just named — what the action
--- is, the verb that performs it, and the ordering rule that put it
--- ahead of everything else.
---
--- Guidance is data, keyed by `decision.KINDS`, so the tool that
--- chooses an action is also the thing that explains it: a kind
--- cannot be added to the ordering and left without an explanation,
--- because `_work/guidance_test.tl` asks the enumeration for its
--- kinds and demands one for each. One kind reads differently by
--- what the item it names delivers — a review of a research
--- handover records its verdict against the exact commit id.
---
--- Pure — no git, no filesystem, no network — and deliberately
--- terse. `next` is read once a session, so what is here is what the
--- tool can state as FACT; the judgment a person or agent brings to
--- the action stays in the `work` skill.

local item = require("_work.item")

local type Item = item.Item

--- The text width guidance is fitted to: the house 90 columns less
--- the two-space indent `next` prints it under.
local WIDTH < const >: integer = 88

--- What each kind is, one note per idea. The notes are prose, not
--- display lines: `lines` folds them to the width, so an edit here
--- is about the words alone.
local NOTES < const >: {string: {string}} = {
  ["finish"] = {
    "An accepted item is ready for the caller to land. Afterwards, "
    .. "`done ID --landed SHA` records the exact landed commit.",
    "A rework carries `request changes`: address the findings supplied out "
    .. "of band, then `take ID --head SHA` hands over the new commit.",
    "A build is yours to finish: commit it, then `take ID --head SHA` records "
    .. "the exact handover. The caller owns push and forge operations.",
  },
  ["review"] = {
    "Claim it first — `take ID` locks the handed-over commit before you read "
    .. "it; an expired claim is available again.",
    "Inspect provider checks on that commit outside gitboard, judge spec vs "
    .. "change, then `verdict ID accept|request-changes --head SHA`.",
    "The verdict comes from a fresh-context reviewer that never held the "
    .. "build; no session accepts its own work.",
  },
  ["pull"] = {
    "The highest-placed todo item passing the spec bar with nothing blocking "
    .. "it. `take ID` is the claim and the lock; the lock is a lease, and a "
    .. "claim idle past it is anyone's again.",
    "Then `show ID`: the spec sidecar is the spec; re-run its measured "
    .. "commands before building.",
  },
  ["refine"] = {
    "Drive the highest-placed todo item toward the spec bar: `show ID` names "
    .. "the gaps, `spec ID FILE --base BASE` writes the refinement back.",
    "Decompose rather than pad: a spec that needs the word \"and\" between two "
    .. "independent changes is two items (`new \"child\" --parent ID`).",
    "Every tree-fact measured, with its command, so the taker re-runs it in "
    .. "seconds.",
  },
  ["triage"] = {
    "An unranked outcome awaits a decision. `rank ID --before X | --after "
    .. "X | --last` positions it among the board's outcomes; `attach ID "
    .. "PARENT` moves it under something else instead.",
    "No outcome fits? Rank it last regardless: it outranks nothing, and an "
    .. "unranked item can never be taken.",
    "Or end it: `done ID` when landed work covers it, `--reason not-planned` for "
    .. "a dead end.",
  },
  ["intake"] = {
    "Decompose the highest-placed outcome that no live work drives: "
    .. "`new \"a piece of it\" --parent ID`.",
    "A child inherits the position of what it hangs under; ordering a NEW "
    .. "outcome against the existing ones takes a `rank`.",
  },
  ["none"] = {
    "Nothing on the board is this session's to move, and the reason above names "
    .. "what is holding.",
    "Stopping here is the answer: work invented to fill the gap lengthens the "
    .. "backlog without moving anything. Report the bottleneck this names and "
    .. "stop.",
  },
}

--- `text` folded at spaces into lines of at most `width` characters.
--- A word longer than the width takes a line to itself rather than
--- being broken mid-word.
--- @param text string The prose to fold
--- @param width integer The greatest line length produced
--- @return {string} The folded lines
local function wrap(text: string, width: integer): {string}
  local out: {string} = {}
  local line = ""
  for word in text:gmatch("%S+") do
    if line == "" then
      line = word
    elseif #line + 1 + #word <= width then
      line = line .. " " .. word
    else
      out[#out + 1] = line
      line = word
    end
  end
  if line ~= "" then
    out[#out + 1] = line
  end
  return out
end

--- The guidance for one action kind, folded to the width `next`
--- prints it at and ready to be indented. Empty for a kind carrying
--- none, so a caller renders nothing rather than a blank block.
--- @param kind string The action kind
--- @return {string} The display lines, empty when the kind is unknown
local function lines(kind: string, _it?: Item): {string}
  local notes = NOTES[kind]
  if notes == nil then
    return {}
  end
  local out: {string} = {}
  for _, note in ipairs(notes) do
    for _, line in ipairs(wrap(note, WIDTH)) do
      out[#out + 1] = line
    end
  end
  return out
end

local record guidance
  WIDTH: integer
  wrap: function(text: string, width: integer): {string}
  lines: function(kind: string, it?: Item): {string}
end

local M: guidance = {
  WIDTH = WIDTH,
  wrap = wrap,
  lines = lines,
}

return M
