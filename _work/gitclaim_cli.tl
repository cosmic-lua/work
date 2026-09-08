--- Thin CLI adapter over the Git-backed claim substrate. It resolves board
--- ids and local product bases, then delegates claim commits and policy to
--- `_work.gitclaim`. Default remote behavior only renders exact push argv;
--- explicit execution uses ordinary Git with caller-owned authentication.
local child = require("cosmic.child")
local claimsession = require("_work.claimsession")
local gate = require("_work.gitgate")
local gitclaim = require("_work.gitclaim")
local gitdraft = require("_work.gitdraft")
local item = require("_work.item")
local prepared = require("_work.prepared")
local repository_map = require("_work.repository_map")
local refs = require("_work.refs")
local store = require("_work.store")
local transport = require("_work.gittransport")

local function resolve_caller(explicit: string): string | nil, string
  local caller = explicit
  if caller == "" then caller = os.getenv("GITBOARD_SESSION") or "" end
  if not claimsession.is_id(caller) then
    return nil, "a claim needs a minted 32-hex session id — run "
    .. "`gitboard session new` and pass --session or set GITBOARD_SESSION"
  end
  return caller, ""
end

--- Resolve a caller only when the command supplied one (directly or through
--- the claim-session environment). Unclaimed metadata can still be edited;
--- once a claim exists, the commit gate requires this value to match it.
local function resolve_optional_caller(explicit: string): string | nil, string
  if explicit == "" and (os.getenv("GITBOARD_SESSION") or "") == "" then
    return "", ""
  end
  return resolve_caller(explicit)
end

local function rev_commit(root: string, name: string): string | nil, string
  local r, err = child.run({"git", "rev-parse", "--verify", name .. "^{commit}"},
    {cwd = root})
  if r == nil then return nil, err end
  if not r.ok then return nil, ("no local commit %s in %s"):format(name, root) end
  return (r.stdout:gsub("%s+$", "")), ""
end

local function default_base(repo: string, base: string): string
  if base ~= "" then return base end
  if repo:find("cosmopolitan", 1, true) then return "master" end
  return "main"
end

--- Product base recorded by an acquisition. Repo-less work uses the board
--- item commit itself; ordinary work uses an already-fetched product base.
local function product_base(s: store.Store, it: item.Item, source_ref: string,
    repo_dir: string): string | nil, string
  if (it.repo or "") == "" then return refs.read_ref(s.root, source_ref) end
  local root, err = repository_map.resolve(s.root, it.repo, repo_dir)
  if root == nil then return nil, err end
  local base = default_base(it.repo, it.base or "")
  return rev_commit(root, "refs/heads/" .. base)
end

--- `session new` deliberately prints only the minted value, so command
--- substitution does not capture a verdict prefix.
local function cmd_session(action: string): integer
  if action ~= "new" then
    io.stderr:write("session needs `new`\n")
    return 1
  end
  print(claimsession.mint())
  return 0
end

--- Claim or renew one atomic set of items. All requests share one clock and
--- one batch id. Any policy refusal or stale item rejects the entire set;
--- disjoint batches still coordinate only through their own item refs.
local function cmd_claim(s: store.Store, ids: {string}, action: gitclaim.Action,
    explicit_session: string, remote: string, repo_dir: string,
    force: boolean, why: string, execute: boolean): integer
  local verb = action == "renew" and "renew"
  or action == "drop" and "drop" or "claim"
  local result_label = action == "renew" and "RENEWED"
  or action == "drop" and "RELEASED" or "ACQUIRED"
  if #ids == 0 then
    return gate.verdict_line(verb, false,
      "REFUSED: at least one ID is required")
  end
  if gitdraft.active(s.root) ~= nil then
    return gate.verdict_line(verb, false,
      "REFUSED: claim operations cannot run inside a draft overlay; "
      .. "publish or discard the draft first")
  end
  local caller, cerr = resolve_caller(explicit_session)
  if caller == nil then
    return gate.verdict_line(verb, false, cerr)
  end
  if repo_dir ~= "" and #ids > 1 then
    return gate.verdict_line(verb, false,
      "REFUSED: --repo-dir is a single-repository override; map repositories "
      .. "for a multi-item claim")
  end
  local all, aerr = store.list(s)
  if all == nil then
    return gate.verdict_line(verb, false, aerr)
  end
  local by_id = item.by_id(all)
  local mode = refs.board_mode(s.root)
  local batch = claimsession.mint()
  local now = os.time()
  local requests: {gitclaim.Request} = {}
  local early: {string: string} = {}
  for _, id in ipairs(ids) do
    local it = by_id[id]
    if it == nil then
      early[id] = "no such item"
    else
      -- Namespace is not derived from resolution: modern completed items
      -- remain under `items`, while legacy imports may live under `ended`.
      -- Select the one exact canonical ref the caller has made available.
      local item_source = mode == "local" and gitclaim.target_item_ref(id)
      or gitclaim.remote_item_ref(remote, id)
      local ended_source = mode == "local" and gitclaim.target_item_ref(id, true)
      or gitclaim.remote_item_ref(remote, id, true)
      local item_sha, iserr = refs.read_ref(s.root, item_source)
      local ended_sha, eserr = refs.read_ref(s.root, ended_source)
      if item_sha == nil then early[id] = iserr
      elseif ended_sha == nil then early[id] = eserr
      elseif item_sha ~= refs.ZERO_SHA and ended_sha ~= refs.ZERO_SHA then
        early[id] = "item exists in both items and ended namespaces"
      end
      local use_ended = item_sha == refs.ZERO_SHA
      local source = use_ended and ended_source or item_source
      local target = gitclaim.target_item_ref(id, use_ended)
      local base = ""
      if action == "take" then
        local found, berr = product_base(s, it, source, repo_dir)
        if found == nil then early[id] = berr else base = found end
      end
      if early[id] == nil then
        requests[#requests + 1] = {
          root = s.root, id = id, source_ref = source, target_ref = target,
          remote = remote, batch = batch, caller = caller, action = action,
          product_base = base, force = force, why = why, now = now,
        }
      end
    end
  end
  local result: gitclaim.BatchResult = next(early) ~= nil
  and {prepared = nil, refused = early}
  or gitclaim.prepare_batch(requests)
  local refused_ids: {string} = {}
  for id in pairs(result.refused) do refused_ids[#refused_ids + 1] = id end
  table.sort(refused_ids)
  for _, id in ipairs(refused_ids) do
    print(("refused %s: %s"):format(id, result.refused[id]))
  end
  if #refused_ids > 0 or result.prepared == nil then
    return gate.verdict_line(verb, false,
      ("batch rejected; no item succeeded; refused=%d"):format(#refused_ids))
  end
  local p = result.prepared
  local function show_members(prefix: string)
    for _, member in ipairs(p.members) do
      print(("%s %s claim=%s branch=%s expires=%d"):format(prefix,
          member.id, member.claim_root, member.branch, member.expires_at))
    end
  end
  if mode == "local" then
    local ok, err = prepared.promote_local(s.root, p.transaction)
    if not ok then
      return gate.verdict_line(verb, false,
        "batch rejected; no item succeeded: " .. err)
    end
    local closed, close_err = store.close(s)
    if not closed then
      return gate.verdict_line(verb, false,
        "claim landed, but the local read model could not be invalidated: "
        .. close_err)
    end
    show_members("confirmed")
    return gate.verdict_line(verb, true,
      ("%s confirmed=%d refused=0"):format(result_label, #p.members))
  end
  local argv, perr = gitclaim.push_argv(p, remote, os.time())
  if argv == nil then
    return gate.verdict_line(verb, false,
      "claim batch could not be published: " .. perr)
  end
  if not execute then
    print(("PREPARED batch=%s items=%d publish-by=%d"):format(
        p.id, #p.members, p.deadline))
    print(transport.render_argv(argv))
    show_members("prepared")
    gate.verdict_line(verb, true,
      ("PREPARED=%d confirmed=0 refused=0. No claim was acquired. "
        .. "Run the printed atomic push, fetch, then `gitboard "
        .. "refresh`; do not act on a prepared item until refresh reports "
        .. "confirmed")
      :format(#p.members))
    return 2
  end
  local pushed, push_err = prepared.execute(s.root, argv)
  if not pushed then
    return gate.verdict_line(verb, false,
      "claim batch publish failed; no item acquired: " .. push_err)
  end
  local fetched, fetch_err = prepared.execute(s.root,
    prepared.fetch_argv(remote))
  if not fetched then
    gate.verdict_line(verb, false,
      "CONFIRMATION PENDING: atomic push completed, but fetch failed: "
      .. fetch_err .. "; do not begin work until refresh confirms it")
    return 2
  end
  local outcomes, refresh_err = prepared.refresh(s.root, remote)
  if outcomes == nil then
    return gate.verdict_line(verb, false,
      "claim confirmation failed: " .. refresh_err)
  end
  local confirmed = false
  for _, outcome in ipairs(outcomes) do
    if outcome.transaction.staging_ref == p.transaction.staging_ref then
      confirmed = outcome.state == "confirmed"
      if not confirmed then
        return gate.verdict_line(verb, false,
          "claim batch was not confirmed: " .. outcome.detail)
      end
    end
  end
  if not confirmed then
    return gate.verdict_line(verb, false,
      "claim confirmation result did not include the prepared batch")
  end
  if p.deadline > 0 and os.time() >= p.deadline then
    return gate.verdict_line(verb, false,
      "claim batch landed but expired before confirmation; no work authority granted")
  end
  local closed, close_err = store.close(s)
  if not closed then
    return gate.verdict_line(verb, false,
      "claim landed, but the local read model could not be invalidated: "
      .. close_err)
  end
  show_members("confirmed")
  return gate.verdict_line(verb, true,
    ("%s confirmed=%d refused=0 (Git execution explicitly requested)")
    :format(result_label, #p.members))
end

local record gitclaim_cli
  resolve_caller: function(explicit: string): string | nil, string
  resolve_optional_caller: function(explicit: string): string | nil, string
  cmd_session: function(action: string): integer
  cmd_claim: function(s: store.Store, ids: {string}, action: gitclaim.Action,
  explicit_session: string, remote: string, repo_dir: string,
  force: boolean, why: string, execute: boolean): integer
end

local M: gitclaim_cli = {
  resolve_caller = resolve_caller,
  resolve_optional_caller = resolve_optional_caller,
  cmd_session = cmd_session,
  cmd_claim = cmd_claim,
}

return M
