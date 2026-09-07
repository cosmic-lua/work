--- Whether one GitHub review counts as a bounce round: a formal
--- `CHANGES_REQUESTED`, or a `COMMENTED` review standing in for one because
--- GitHub refuses `REQUEST_CHANGES` on the token's own PR
--- (`_work.ghwrite.post_review`'s marked-COMMENT fallback, cosmic#1768).
--- `_work.gh`'s `latest_request_changes` (picking WHICH bounce a rework
--- hands back against) and `_work.brief`'s `round_context` (counting HOW
--- MANY there have been) both need the same yes/no, so it lives here once
--- rather than as two copies that can drift apart.
---
--- Takes the review's `state` and `body` rather than a whole review record:
--- neither caller's `Review` type is this module's to depend on, and the
--- predicate only ever reads these two fields.

--- The exact first line a marked-COMMENT bounce carries. A mention later in
--- the body, on a later line, or with leading text or space, is a plain
--- comment, never a bounce — `is_bounce`'s callers rely on this being exact.
local REQUEST_CHANGES_MARKER = "request-changes:"
local REJECT_MARKER = "reject:"

--- Whether one review counts as a bounce round.
--- @param state string The review's state ("CHANGES_REQUESTED", "COMMENTED", ...)
--- @param body string The review's verbatim body
--- @return boolean Whether this review is a bounce, formal or marked
local function is_bounce(state: string, body: string): boolean
  if state == "CHANGES_REQUESTED" then
    return true
  end
  if state ~= "COMMENTED" then
    return false
  end
  local first = body:match("^([^\n]*)") or body
  return first == REQUEST_CHANGES_MARKER or first == REJECT_MARKER
end

local record bounce
  is_bounce: function(state: string, body: string): boolean
  REQUEST_CHANGES_MARKER: string
  REJECT_MARKER: string
end

local M: bounce = {
  is_bounce = is_bounce,
  REQUEST_CHANGES_MARKER = REQUEST_CHANGES_MARKER,
  REJECT_MARKER = REJECT_MARKER,
}

return M
