--- spec: replace an item's spec sidecar — the verb that moves the
--- DEFINITION of work, beside `_work.gitverbs`' state verbs, which
--- move an item's MOTION (the same split `_work/gitspec_test.tl`
--- already tests along). The write is a compare-and-swap against
--- `base` proving the writer read what is there. An in-flight item's
--- spec is its claim holder's to move (`gate.spec_refusal`) — a
--- foreign write onto a live claim needs `--force --why`, same as
--- taking one over. A named session joins `it.speccers` — `builders`'
--- counterpart for spec authorship — in the SAME commit as the
--- sidecar; a flag-shaped name is refused before anything is staged
--- (`item.record_involvement`).
local fs = require("cosmic.fs")
local gate = require("_work.gitgate")
local item = require("_work.item")
local store = require("_work.store")

--- Split text into its lines, with no trailing empty entry for a final
--- newline — "" splits to no lines at all.
--- @param text string The text
--- @return {string} Its lines, in order
local function lines_of(text: string): {string}
  local out: {string} = {}
  if text == "" then
    return out
  end
  local pos = 1
  while true do
    local nl = text:find("\n", pos, true)
    if nl == nil then
      out[#out + 1] = text:sub(pos)
      break
    end
    out[#out + 1] = text:sub(pos, nl - 1)
    pos = nl + 1
    if pos > #text then
      break
    end
  end
  return out
end

--- The size of replacing `old` with `new`, as a per-line multiset
--- (bag) count: a line present in `new` one more time than in `old`
--- is one line added, and the reverse one line removed — line MOVES
--- and edits within a line are not tracked, only counts by content.
--- @param old string The stored text
--- @param new string The replacement text
--- @return integer Lines added
--- @return integer Lines removed
local function diffstat(old: string, new: string): integer, integer
  local delta: {string: integer} = {}
  for _, line in ipairs(lines_of(old)) do
    delta[line] = (delta[line] or 0) - 1
  end
  for _, line in ipairs(lines_of(new)) do
    delta[line] = (delta[line] or 0) + 1
  end
  local added = 0
  local removed = 0
  for _, d in pairs(delta) do
    if d > 0 then
      added = added + d
    else
      removed = removed - d
    end
  end
  return added, removed
end

--- @param s store.Store The store
--- @param id string The item whose spec is replaced
--- @param file string Path to the replacement markdown
--- @param base string | nil The spec text the caller read, as a file path
--- @param session string | nil The session making the write
--- @param force boolean | nil Rewrite a foreign LIVE claim's spec
--- @param why string | nil Why --force was needed
--- @return integer Exit code
local function cmd_spec(s: store.Store, id: string, file: string,
    base?: string, session?: string, force?: boolean, why?: string): integer
  local frc = force or false
  local rsn = why or ""
  local forced = gate.force_refusal(frc, rsn)
  if forced then
    return gate.verdict_line("spec", false, "REFUSED: " .. forced)
  end
  local it, lerr = store.load(s, id)
  if it == nil then
    return gate.verdict_line("spec", false, lerr)
  end
  if not frc then
    local c, cerr = store.read(s)
    if c == nil then
      return gate.verdict_line("spec", false, cerr)
    end
    local refusal, srerr = gate.spec_refusal(c, it, session or "")
    if srerr ~= "" then
      return gate.verdict_line("spec", false, srerr)
    end
    if refusal then
      return gate.verdict_line("spec", false, refusal)
    end
  end
  local body, rerr = fs.read(file)
  if body == nil then
    return gate.verdict_line("spec", false, rerr)
  end
  local current = store.read_spec(s, id)
  local stale = gate.base_refusal(current, base or "", id)
  if stale then
    return gate.verdict_line("spec", false, stale)
  end
  if body == current then
    return gate.verdict_line("spec", true,
      ("%s's spec is unchanged — nothing written"):format(id:sub(1, 8)))
  end
  local who = session or ""
  if who ~= "" then
    local recorded, ierr = item.record_involvement(it.speccers, who)
    if not recorded then
      return gate.verdict_line("spec", false, "REFUSED: " .. ierr)
    end
  end
  local ok, err = gate.commit_and_publish(s, it, body,
    ("spec %s%s"):format(id:sub(1, 8), gate.forced_suffix(frc, rsn)),
    "spec", nil, session)
  if not ok then
    return gate.verdict_line("spec", false, err)
  end
  if store.is_noop(err) then
    return gate.verdict_line("spec", true, err)
  end
  local added, removed = diffstat(current, body)
  return gate.verdict_line("spec", true,
    ("%s's spec replaced (+%d/-%d lines)"):format(id:sub(1, 8), added, removed))
end

local record gitspec
  cmd_spec: function(s: store.Store, id: string, file: string,
  base?: string, session?: string, force?: boolean, why?: string): integer
end

local M: gitspec = {
  cmd_spec = cmd_spec,
}

return M
