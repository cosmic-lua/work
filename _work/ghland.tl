--- The landing an accepted verdict performs on the provider, and the
--- only module that requires `_work.apiauth`. gitboard's default is
--- unchanged and unconditional: the caller lands the work itself and
--- `_work.api` refuses every request locally. A caller that would
--- rather gitboard did the landing says so by naming the environment
--- variable holding its token (`_work.apiauth`); only then does an
--- accept reach GitHub at all.
---
--- The transport is installed for the landing and taken back down
--- afterward, so an accept that lands leaves the process exactly as
--- refusing as it found it — activation is not a mode the rest of the
--- run inherits.
---
--- The sequence is the one gitboard performed before landing became
--- the caller's job: squash-merge the judged head, and on a refusal
--- that means "not directly mergeable right now" (branch protection,
--- a merge queue, a not-yet-mergeable state) arm auto-merge instead,
--- which lands the same accept once the repo's own requirements
--- clear. Nothing here can fail the verdict: the judgment is already
--- recorded when this runs, and a failed landing is reported on the
--- verdict line, never returned as a refusal.
local apiauth = require("_work.apiauth")
local gh = require("_work.gh")
local ghwrite = require("_work.ghwrite")
local item = require("_work.item")
local store = require("_work.store")

--- What performs an activated landing's requests: `cosmic.fetch.fetch`'s
--- own shape, threaded through from the verb so a test proves the
--- sequence against a capture instead of a live GitHub write.
local type Transport = apiauth.Transport

--- What one landing attempt did. `attempted` false is the ordinary
--- case — no pull request recorded, or no transport activated — and
--- means nothing at all was sent.
local record Landing
  --- Whether a provider write was attempted.
  attempted: boolean
  --- The merge commit GitHub reported; "" unless it merged directly.
  merged: string
  --- Auto-merge armed instead of a direct merge.
  armed: boolean
  --- The landing failure, "" when none.
  error: string
end

--- Nothing was sent: the shared shape for "no pull request to land"
--- and "no transport activated", which read identically to a caller.
--- @return Landing An untouched result
local function untouched(): Landing
  return {attempted = false, merged = "", armed = false, error = ""}
end

--- The pull request an item's recorded navigation URL names. That URL
--- is the only place the data model holds a pull request, so it is
--- what a landing acts on; an item carrying no URL, or one pointing
--- somewhere this codec cannot write, simply has nothing to land.
--- @param external_url string The item's recorded navigation URL
--- @return string owner/name, "" when the URL names no GitHub pull request
--- @return integer The pull request number, 0 when there is none
local function pull_of(external_url: string): string, integer
  local owner, name, number = external_url:match(
    "^https://github%.com/([%w%-%._]+)/([%w%-%._]+)/pull/(%d+)")
  if owner == nil or name == nil or number == nil then
    return "", 0
  end
  return ("%s/%s"):format(owner, name), math.tointeger(tonumber(number)) or 0
end

--- Whether a refused merge means "not directly mergeable right now"
--- rather than a real failure. GitHub answers 405 when its own
--- requirements hold the merge back and 409 when the head disagrees
--- with the sha the request was guarded by; both are exactly what
--- auto-merge exists to wait out. `merge_pull` carries the status
--- verbatim in its message for this test.
--- @param msg string The rendered merge failure
--- @return boolean True when arming auto-merge is the right next step
local function is_held_back(msg: string): boolean
  return msg:find("HTTP 405", 1, true) ~= nil
  or msg:find("HTTP 409", 1, true) ~= nil
end

--- The landing itself, with a transport already installed.
--- @param s store.Store The store
--- @param repo string owner/name
--- @param number integer The pull request number
--- @param head string The judged commit the merge is guarded by
--- @return Landing What the attempt did
local function attempt(s: store.Store, repo: string, number: integer,
    head: string): Landing
  local merged, msg = ghwrite.merge_pull(s, repo, number, head)
  if merged then
    return {attempted = true, merged = msg, armed = false, error = ""}
  end
  if not is_held_back(msg) then
    return {attempted = true, merged = "", armed = false, error = msg}
  end
  -- Auto-merge is a GraphQL mutation addressing the request by node
  -- id, which the REST merge refusal does not carry — so the fallback
  -- costs one read of the request it is about to arm.
  local p, perr = gh.pull(s, number, repo)
  if p == nil then
    return {attempted = true, merged = "", armed = false,
      error = ("%s; then reading the request to arm auto-merge: %s")
      :format(msg, perr)}
  end
  local armed, aerr = ghwrite.enable_auto_merge(s, repo, number, p.node_id)
  if not armed then
    return {attempted = true, merged = "", armed = false, error = aerr}
  end
  return {attempted = true, merged = "", armed = true, error = ""}
end

--- Land an accept that has already been recorded. Does nothing at all
--- unless the item names a pull request AND the caller has activated
--- provider transport; the activation is undone before this returns.
--- @param s store.Store The store
--- @param it item.Item The item whose accept was just recorded
--- @param head string The judged commit
--- @param send Transport | nil What the activated transport performs
--- requests with (defaults to `cosmic.fetch.fetch`); a test passes a
--- capture instead
--- @return Landing What the landing did, if anything
local function land(s: store.Store, it: item.Item, head: string,
    send?: Transport): Landing
  local repo, number = pull_of(it.external_url or "")
  if repo == "" or number == 0 then
    return untouched()
  end
  -- The refusal is deliberately dropped: not opting in is the default,
  -- not a fault, and the caller who did not ask for provider transport
  -- has nothing to read about it on a verdict line.
  local live, _why = apiauth.activate(nil, send)
  if not live then
    return untouched()
  end
  local result = attempt(s, repo, number, head)
  local _restored = apiauth.deactivate()
  return result
end

--- What a landing adds to the verdict line. Empty when nothing was
--- attempted, which is why an unactivated accept still prints exactly
--- the line it always did. A failure names itself and hands the work
--- back rather than pretending the merge is in motion; the verdict
--- stands either way.
--- @param l Landing What `land` reported
--- @return string The suffix, "" when there is nothing to say
local function note(l: Landing): string
  if not l.attempted then
    return ""
  end
  if l.error ~= "" then
    return (" — landing failed (%s), land it by hand"):format(l.error)
  end
  if l.merged ~= "" then
    return (" — merged %s"):format(l.merged:sub(1, 12))
  end
  if l.armed then
    return " — auto-merge armed, it lands when the repo's checks clear"
  end
  return ""
end

local record ghland
  type Transport = Transport
  type Landing = Landing
  pull_of: function(external_url: string): string, integer
  land: function(s: store.Store, it: item.Item, head: string,
  send?: Transport): Landing
  note: function(l: Landing): string
end

local M: ghland = {
  pull_of = pull_of,
  land = land,
  note = note,
}

return M
