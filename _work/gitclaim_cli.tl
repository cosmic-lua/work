--- Thin CLI adapter over the Git-backed claim substrate. It resolves board
--- ids and local product bases, then delegates claim commits and policy to
--- `_work.gitclaim`. Default remote behavior only renders exact push argv;
--- explicit execution uses ordinary Git with caller-owned authentication.
local child = require("cosmic.child")
local claimsession = require("_work.claimsession")
local commit_evidence = require("_work.commit_evidence")
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

--- The target branch's configured remote-tracking ref (`git for-each-ref
--- --format=%(upstream)`), "" when the branch tracks nothing. Reading the
--- branch's own tracking configuration, rather than assuming a remote name,
--- is what lets this compare against whichever remote the checkout actually
--- follows.
local function tracking_ref(root: string, base: string): string | nil, string
  local r, err = child.run({"git", "for-each-ref", "--format=%(upstream)",
      "refs/heads/" .. base}, {cwd = root})
  if r == nil then return nil, err end
  if not r.ok then
    return nil, ("cannot read tracking configuration for %s: %s")
    :format(base, r.stderr)
  end
  return (r.stdout:gsub("%s+$", "")), ""
end

--- Whether `local_sha` is a strict ancestor of `tracking`'s current value —
--- the shape a checkout whose local target branch never fast-forwarded past
--- an upstream advance takes. Returns "" (nothing wrong) when the branch
--- tracks nothing, the tracking ref is not itself fetched yet, or the two
--- already agree; a non-"" candidate value names what the tracking ref
--- currently resolves to, for the caller to act on.
local function stale_target(root: string, base: string,
    local_sha: string): string, string
  local tracking, terr = tracking_ref(root, base)
  if tracking == nil then return "", terr end
  if tracking == "" then return "", "" end
  local remote_sha, _rerr = rev_commit(root, tracking)
  if remote_sha == nil then return "", "" end
  if remote_sha == local_sha then return "", "" end
  local r, err = child.run({"git", "merge-base", "--is-ancestor", local_sha,
      remote_sha}, {cwd = root})
  if r == nil then return "", err end
  if not r.ok and r.code ~= 1 then
    return "", ("git merge-base failed: %s"):format(r.stderr)
  end
  if not r.ok then return "", "" end -- diverged or ahead: not this guard's case
  return remote_sha, ""
end

--- Fetch the branch's configured remote and fast-forward the local branch to
--- match, only ever moving it to a value the fetch itself proves current.
--- Requires the branch's tracking configuration to name a remote (an
--- explicit `--repo-dir`/mapping override with no such configuration cannot
--- be resolved this way).
local function fetch_forward(root: string, base: string, local_sha: string,
    expected: string): string | nil, string
  local remote_r, err = child.run({"git", "config", "--local", "--get",
      "branch." .. base .. ".remote"}, {cwd = root})
  if remote_r == nil then return nil, err end
  if not remote_r.ok then
    return nil, ("%s has no configured remote to fetch"):format(base)
  end
  local remote = remote_r.stdout:gsub("%s+$", "")
  local fetched = child.run({"git", "fetch", remote}, {cwd = root})
  if fetched == nil or not fetched.ok then
    return nil, ("git fetch %s failed: %s"):format(remote,
      fetched ~= nil and fetched.stderr or "could not run git")
  end
  local tracking, terr = tracking_ref(root, base)
  if tracking == nil or tracking == "" then
    return nil, terr ~= "" and terr or ("%s lost its tracking configuration"):format(base)
  end
  local remote_sha, rerr = rev_commit(root, tracking)
  if remote_sha == nil then return nil, rerr end
  local ahead_r, aerr = child.run({"git", "merge-base", "--is-ancestor",
      expected, remote_sha}, {cwd = root})
  if ahead_r == nil then return nil, aerr end
  if not ahead_r.ok then
    return nil, ("%s's tracking ref %s no longer descends from the fetched %s")
    :format(base, tracking, expected)
  end
  local updated = child.run({"git", "update-ref", "refs/heads/" .. base,
      remote_sha, local_sha}, {cwd = root})
  if updated == nil or not updated.ok then
    return nil, ("git update-ref could not fast-forward %s: %s"):format(base,
      updated ~= nil and updated.stderr or "could not run git")
  end
  return remote_sha, ""
end

--- Refusal text when `base` cannot reach `handover` — the shape a review
--- claim takes once the local product repository has moved on, unrelated to
--- this item, since the handover was recorded. "" when `handover` is "" (no
--- recorded handover to protect) or `base` already reaches it.
--- `worktree ID --review` cannot resolve this: it requires an active claim
--- on ID, and the claim this message is refusing is exactly what would
--- supply one — naming it here would send the caller in a circle. The
--- remedy that actually works is repositioning `branch_name` — the LOCAL
--- PRODUCT REPO's own branch that `claim` reads `base` from — to (or
--- behind) the recorded handover, then retrying `claim` against that same
--- repo.
local function handover_ancestry_refusal(root: string, id: string,
    branch_name: string, base: string, handover: string): string
  if handover == "" then return "" end
  local lineage, _lerr = commit_evidence.verify_lineage(root, base, handover)
  if lineage ~= nil then return "" end
  return ("%s already has a commit handover (%s) that local %s (%s) cannot "
    .. "reach — a fresh review claim must not silently capture an unrelated "
    .. "base; reposition %s in %s to (or behind) the handover "
    .. "(e.g. `git -C %s update-ref refs/heads/%s %s`), then retry "
    .. "`claim --repo-dir %s`")
  :format(id:sub(1, 8), handover, base, base:sub(1, 12), branch_name, root,
    root, branch_name, handover, root)
end

--- Product base recorded by an acquisition. Repo-less work uses the board
--- item commit itself; ordinary work uses an already-fetched product base.
--- A local target branch behind its own configured remote-tracking ref is
--- never captured silently: it is refused with the exact commands that
--- resolve it, unless `fetch_base` explicitly authorizes running them here.
--- An item already carrying a recorded handover additionally requires the
--- resolved base to still reach it, so a review claim never recaptures a
--- base the handover cannot descend from (see `handover_ancestry_refusal`).
local function product_base(s: store.Store, it: item.Item, source_ref: string,
    repo_dir: string, fetch_base: boolean): string | nil, string
  if (it.repo or "") == "" then return refs.read_ref(s.root, source_ref) end
  local root, err = repository_map.resolve(s.root, it.repo, repo_dir)
  if root == nil then return nil, err end
  local base = default_base(it.repo, it.base or "")
  local local_sha, lerr = rev_commit(root, "refs/heads/" .. base)
  if local_sha == nil then return nil, lerr end
  local candidate, serr = stale_target(root, base, local_sha)
  if serr ~= "" then return nil, serr end
  local resolved = local_sha
  if candidate ~= "" then
    if not fetch_base then
      return nil, ("local %s (%s) is behind its tracking ref (%s) — run "
        .. "`git -C %s fetch` then `git -C %s update-ref refs/heads/%s %s`, "
        .. "or re-run claim with --fetch-base to do it here"):format(
        base, local_sha:sub(1, 12), candidate:sub(1, 12), root, root, base,
        candidate)
    end
    local forwarded, ferr = fetch_forward(root, base, local_sha, candidate)
    if forwarded == nil then return nil, ferr end
    resolved = forwarded
  end
  local refusal = handover_ancestry_refusal(root, it.id, base, resolved,
    it.handover_head or "")
  if refusal ~= "" then return nil, refusal end
  return resolved, ""
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
    force: boolean, why: string, execute: boolean, fetch_base?: boolean): integer
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
        local found, berr = product_base(s, it, source, repo_dir,
          fetch_base or false)
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
  force: boolean, why: string, execute: boolean, fetch_base?: boolean): integer
end

local M: gitclaim_cli = {
  resolve_caller = resolve_caller,
  resolve_optional_caller = resolve_optional_caller,
  cmd_session = cmd_session,
  cmd_claim = cmd_claim,
}

return M
