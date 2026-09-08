--- Thin CLI adapter over the Git-backed claim substrate. It resolves board
--- ids and local product bases, then delegates claim commits and policy to
--- `_work.gitclaim`. Default remote behavior only renders exact push argv;
--- explicit execution uses ordinary Git with caller-owned authentication.
local child = require("cosmic.child")
local str = require("cosmic.string")
local claimsession = require("_work.claimsession")
local gate = require("_work.gitgate")
local gitclaim = require("_work.gitclaim")
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

--- Claim or renew an independent set of items. All requests share one clock;
--- each gets its own staging ref and CAS, so partial success is preserved.
local function cmd_claim(s: store.Store, ids: {string}, action: gitclaim.Action,
    explicit_session: string, remote: string, repo_dir: string,
    force: boolean, why: string, execute: boolean): integer
  local verb = action == "renew" and "renew"
  or action == "drop" and "drop" or "claim"
  if #ids == 0 then
    return gate.verdict_line(verb, false,
      "REFUSED: at least one ID is required")
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
  local result = gitclaim.prepare_batch(requests)
  for id, err in pairs(early) do result.refused[id] = err end
  local confirmed, staged, failed = #result.already_owned, 0, 0
  for _, owned in ipairs(result.already_owned) do
    print(("owned %s claim=%s branch=%s expires=%d"):format(
        owned.id, owned.claim_root, owned.branch, owned.expires_at))
  end
  local pushed: {gitclaim.Prepared} = {}
  for _, p in ipairs(result.prepared) do
    if mode == "local" then
      local ok, err = refs.update_ref(s.root, p.target_ref, p.new_sha, p.old_sha)
      if ok then
        local was_confirmed, ferr = gitclaim.confirm(s.root, p.target_ref, p)
        if was_confirmed then
          confirmed = confirmed + 1
          print(("confirmed %s claim=%s branch=%s expires=%d"):format(
              p.id, p.claim_root, p.branch, p.expires_at))
        else
          failed = failed + 1
          io.stderr:write(("claim %s confirmation failed: %s\n"):format(p.id, ferr))
        end
      else
        failed = failed + 1
        io.stderr:write(("claim %s lost local CAS: %s\n"):format(p.id, err))
      end
    elseif execute then
      local ok, err = prepared.execute(s.root, p.push_argv)
      if ok then pushed[#pushed + 1] = p else
        failed = failed + 1
        io.stderr:write(("claim %s publish failed: %s\n"):format(p.id, err))
      end
    else
      staged = staged + 1
      print(transport.render_argv(p.push_argv))
      print(("PREPARED %s claim=%s branch=%s expires=%d"):format(
          p.id, p.claim_root, p.branch, p.expires_at))
    end
  end
  if mode == "remote" and execute and #pushed > 0 then
    local fetched, ferr = prepared.execute(s.root, prepared.fetch_argv(remote))
    if not fetched then
      io.stderr:write("claim confirmation fetch failed: " .. ferr .. "\n")
      gate.verdict_line(verb, false,
        ("CONFIRMATION PENDING: %d push(es) completed, but the fetched refs "
          .. "could not be refreshed; a claim may have landed. Do not begin "
          .. "work until `gitboard refresh --execute --remote %s` confirms it")
        :format(#pushed, remote))
      return 2
    else
      for _, p in ipairs(pushed) do
        local source = str.replace(p.target_ref, "refs/heads/",
          "refs/remotes/" .. remote .. "/", 1)
        local ok, err = gitclaim.confirm(s.root, source, p)
        if ok then
          confirmed = confirmed + 1
          print(("confirmed %s claim=%s branch=%s expires=%d"):format(
              p.id, p.claim_root, p.branch, p.expires_at))
        else
          failed = failed + 1
          io.stderr:write(("claim %s confirmation failed: %s\n"):format(p.id, err))
        end
      end
    end
  end
  -- Local-mode promotion moves canonical refs behind the Store handle's
  -- already-open read model. Close it once after the batch so the next
  -- command observes the confirmed claim and refreshes its write lease.
  -- Without this, a later holder mutation can be refused as though the
  -- previous claimant still owned the item.
  if mode == "local" and confirmed > 0 then
    local closed, close_err = store.close(s)
    if not closed then
      return gate.verdict_line(verb, false,
        "claim landed, but the local read model could not be invalidated: "
        .. close_err)
    end
  end
  local refused_ids: {string} = {}
  for id in pairs(result.refused) do refused_ids[#refused_ids + 1] = id end
  table.sort(refused_ids)
  for _, id in ipairs(refused_ids) do
    failed = failed + 1
    print(("refused %s: %s"):format(id, result.refused[id]))
  end
  if confirmed == 0 and staged == 0 then
    return gate.verdict_line(verb, false,
      ("no item succeeded; refused=%d"):format(failed))
  end
  if staged > 0 then
    gate.verdict_line(verb, true,
      ("PREPARED=%d confirmed=%d refused=%d. No claim was acquired for a "
        .. "prepared item. Run the printed push command(s), fetch, then `gitboard "
        .. "refresh`; do not act on a prepared item until refresh reports "
        .. "confirmed")
      :format(staged, confirmed, failed))
    return 2
  end
  return gate.verdict_line(verb, true,
    ("ACQUIRED confirmed=%d refused=%d%s"):format(confirmed, failed,
      execute and " (Git execution explicitly requested)" or ""))
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
