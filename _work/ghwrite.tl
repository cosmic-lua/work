--- The GitHub writes a verdict performs on a pull request: landing an
--- accept (merge, or arm auto-merge when a direct merge is refused),
--- posting the formal review a request-changes or reject verdict
--- carries, and closing the request a reject ends. `_work.gh` holds
--- the board's reads; this holds the writes `_work.gitverdict` composes
--- them with — split out to keep `gh.tl` under the file cap.
---
--- Each wrapper is a thin `boolean, string` shape: true and a payload
--- the caller needs (a merge commit sha, "" otherwise) on success,
--- false and the rendered error on failure. `merge_pull`'s failure
--- message carries the HTTP status verbatim (`_work.api.error_of`'s
--- own rendering) rather than a paraphrase, because the caller reads
--- it to decide whether a refused merge falls back to auto-merge.
local api = require("_work.api")
local json = require("cosmic.json")
local store = require("_work.store")

--- Land a pull request by squash-merging it. The `sha` field makes a
--- head that moved since the review a refused merge, not a merge of
--- unreviewed code — GitHub answers 409 when the request's current
--- head disagrees with it.
--- @param s store.Store The store
--- @param repo string owner/name
--- @param number integer The PR number
--- @param sha string The judged head
--- @return boolean True once GitHub completes the merge
--- @return string The merge commit sha on success; on failure, the
--- rendered error (carrying the HTTP status, so a caller can match
--- "HTTP 405"/"HTTP 409" to decide on the auto-merge fallback)
local function merge_pull(s: store.Store, repo: string, number: integer,
    sha: string): boolean, string
  local path = ("/repos/%s/pulls/%d/merge"):format(repo, number)
  local payload, jerr = json.encode({merge_method = "squash", sha = sha})
  if payload == nil then
    return false, "encoding the merge request: " .. tostring(jerr)
  end
  local res, err = api.call("PUT", path, s.root, payload)
  if res == nil then
    return false, err
  end
  if not api.is_success(res.status) then
    return false, api.error_of("PUT", path, res)
  end
  local v = res.value
  local merge_sha = sha
  if v is {string: any} then
    merge_sha = tostring(v["sha"] or sha)
  end
  return true, merge_sha
end

-- The distinguishing substring of the Anthropic-operated proxy's
-- refusal of GraphQL from a Claude Code session — distinct from any
-- other 403 (a bad token, a missing scope, a repo permission), none
-- of which this fallback should mask.
local CLAUDE_SESSION_GRAPHQL_REFUSAL < const > =
"GraphQL is not available from Claude Code sessions"

--- Arm auto-merge via the CCR REST route
--- (`PUT /repos/{owner}/{repo}/pulls/{n}/ccr/auto_merge`), the fallback
--- `enable_auto_merge` retries with when the GraphQL mutation itself is
--- unavailable rather than merely refused by the repo or the request.
--- @param s store.Store The store
--- @param repo string owner/name
--- @param number integer The PR number
--- @return boolean True once GitHub reports auto-merge enabled
--- @return string Error message on failure
local function ccr_enable_auto_merge(s: store.Store, repo: string,
    number: integer): boolean, string
  local path = ("/repos/%s/pulls/%d/ccr/auto_merge"):format(repo, number)
  local payload, jerr = json.encode({merge_method = "squash"})
  if payload == nil then
    return false, "encoding the auto-merge request: " .. tostring(jerr)
  end
  local res, err = api.call("PUT", path, s.root, payload)
  if res == nil then
    return false, err
  end
  if not api.is_success(res.status) then
    return false, api.error_of("PUT", path, res)
  end
  local v = res.value
  if v is {string: any} and v["enabled"] == true then
    return true, ""
  end
  return false, ("PUT %s: response did not report auto-merge enabled"):format(path)
end

--- Arm auto-merge on a pull request GitHub refused to merge directly
--- (branch protection, a merge queue, a not-yet-mergeable state): the
--- accept still stands, and the merge completes once the repo's own
--- requirements clear.
---
--- Attempts the `enablePullRequestAutoMerge` GraphQL mutation first —
--- this stays correct in any environment where GraphQL is available
--- (a plain CI runner with an unrestricted PAT, for instance). When
--- that call is refused with a 403 whose body matches the Claude Code
--- proxy's own refusal (`CLAUDE_SESSION_GRAPHQL_REFUSAL`), GraphQL
--- itself is unavailable rather than merely declined, so this retries
--- via the CCR REST route instead. A 403 that does NOT match — a bad
--- token, a missing scope, a repo permission — is a different, real
--- refusal a caller needs to see, so it is surfaced as-is, never
--- retried.
--- @param s store.Store The store
--- @param repo string owner/name
--- @param number integer The PR number
--- @param node_id string The pull request's GraphQL node id
--- @return boolean True once GitHub accepts the mutation
--- @return string Error message on failure
local function enable_auto_merge(s: store.Store, repo: string,
    number: integer, node_id: string): boolean, string
  local query = "mutation($id: ID!) { enablePullRequestAutoMerge("
  .. "input: {pullRequestId: $id, mergeMethod: SQUASH}) "
  .. "{ clientMutationId } }"
  local payload, jerr = json.encode({query = query,
      variables = {id = node_id}})
  if payload == nil then
    return false, "encoding the auto-merge mutation: " .. tostring(jerr)
  end
  local res, err = api.call("POST", "/graphql", s.root, payload)
  if res == nil then
    return false, err
  end
  -- GraphQL answers 200 even on a mutation failure, with the failure
  -- named in an `errors` array rather than the HTTP status.
  local v = res.value
  if v is {string: any} then
    local errs = v["errors"]
    if errs is {any} and #errs > 0 then
      local msg = "GraphQL error"
      local first = errs[1]
      if first is {string: any} then
        msg = tostring(first["message"] or msg)
      end
      return false, ("POST /graphql: %s"):format(msg)
    end
  end
  if not api.is_success(res.status) then
    if res.status == 403 and v is {string: any} then
      local msg = tostring(v["message"] or "")
      if msg:find(CLAUDE_SESSION_GRAPHQL_REFUSAL, 1, true) ~= nil then
        return ccr_enable_auto_merge(s, repo, number)
      end
    end
    return false, api.error_of("POST", "/graphql", res)
  end
  return true, ""
end

--- `kind`'s own marker line, prefixed to `body` — the shape
--- `_work.gh.latest_request_changes` matches regardless of whether the
--- marked body rides a `REQUEST_CHANGES` review or a `COMMENT` one, so
--- a rework brief still fills either way.
--- @param kind string "request changes" | "reject"
--- @param body string The review's body text
--- @return string The marked body
local function marked(kind: string, body: string): string
  local marker = kind == "reject" and "reject:" or "request-changes:"
  return marker .. "\n" .. body
end

--- Post a formal review on a pull request — the `REQUEST_CHANGES`
--- event a rework hand-back looks for (`_work.gh.latest_request_changes`);
--- a plain comment never satisfies it. Except on the token's OWN pull
--- request (`--open` opens every PR under this same token): GitHub
--- refuses `REQUEST_CHANGES`/`APPROVE` there but allows `COMMENT`, so
--- this posts a marked `COMMENT` instead. Two ways land on that same
--- own-PR case: the cheap one first — `_work.api.own_login`'s `GET
--- /user` compared against `author_login` — and, only when a
--- REQUEST_CHANGES attempt still comes back 422, one retry as a marked
--- COMMENT. The second path exists because an app installation token
--- has no `GET /user` to answer for (it answers for the app, not a
--- user), so `own_login` fails and the cheap check can never fire for
--- it; GitHub's 422 is that same own-PR refusal surfacing at the
--- write instead. When the own-login read merely errors (no token,
--- network) and the write is NOT on its own PR, this still attempts
--- REQUEST_CHANGES first, exactly as before.
--- @param s store.Store The store
--- @param repo string owner/name
--- @param number integer The PR number
--- @param sha string The judged head the review is pinned to
--- @param body string The review's body text
--- @param kind string "request changes" | "reject" — which marker a
--- own-PR `COMMENT` carries
--- @param author_login string The PR's own author login (`.author_login`)
--- @return boolean True once GitHub records the review
--- @return string Error message on failure; on success, "comment-fallback"
--- when the 422 retry is what actually posted, else ""
local function post_review(s: store.Store, repo: string, number: integer,
    sha: string, body: string, kind: string, author_login: string):
  boolean, string
  local path = ("/repos/%s/pulls/%d/reviews"):format(repo, number)
  local event = "REQUEST_CHANGES"
  local own_body = body
  local login, _lerr = api.own_login(s.root)
  if login ~= nil and login ~= "" and author_login ~= nil and author_login ~= ""
  and login:lower() == author_login:lower() then
    event = "COMMENT"
    own_body = marked(kind, body)
  end
  local payload, jerr = json.encode({event = event,
      commit_id = sha, body = own_body})
  if payload == nil then
    return false, "encoding the review: " .. tostring(jerr)
  end
  local res, err = api.call("POST", path, s.root, payload)
  if res == nil then
    return false, err
  end
  if api.is_success(res.status) then
    return true, ""
  end
  if event ~= "REQUEST_CHANGES" or res.status ~= 422 then
    return false, api.error_of("POST", path, res)
  end
  local retry_payload, rjerr = json.encode({event = "COMMENT",
      commit_id = sha, body = marked(kind, body)})
  if retry_payload == nil then
    return false, "encoding the review: " .. tostring(rjerr)
  end
  local rres, rerr = api.call("POST", path, s.root, retry_payload)
  if rres == nil then
    return false, rerr
  end
  if not api.is_success(rres.status) then
    return false, api.error_of("POST", path, rres)
  end
  return true, "comment-fallback"
end

--- Close a pull request — the second half of a reject, run after its
--- formal review is posted.
--- @param s store.Store The store
--- @param repo string owner/name
--- @param number integer The PR number
--- @return boolean True once GitHub closes it
--- @return string Error message on failure
local function close_pull(s: store.Store, repo: string, number: integer):
  boolean, string
  local path = ("/repos/%s/pulls/%d"):format(repo, number)
  local payload, jerr = json.encode({state = "closed"})
  if payload == nil then
    return false, "encoding the close request: " .. tostring(jerr)
  end
  local res, err = api.call("PATCH", path, s.root, payload)
  if res == nil then
    return false, err
  end
  if not api.is_success(res.status) then
    return false, api.error_of("PATCH", path, res)
  end
  return true, ""
end

local record ghwrite
  merge_pull: function(s: store.Store, repo: string, number: integer,
  sha: string): boolean, string
  enable_auto_merge: function(s: store.Store, repo: string, number: integer,
  node_id: string): boolean, string
  post_review: function(s: store.Store, repo: string, number: integer,
  sha: string, body: string, kind: string, author_login: string): boolean, string
  close_pull: function(s: store.Store, repo: string, number: integer):
  boolean, string
end

local M: ghwrite = {
  merge_pull = merge_pull,
  enable_auto_merge = enable_auto_merge,
  post_review = post_review,
  close_pull = close_pull,
}

return M
