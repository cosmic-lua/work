--- Git-native prepared board transactions. A mutation's durable
--- contract is one manifest commit under `refs/gitboard/prepared/*`.
--- The commit records only compare-and-swap triples: target ref,
--- expected object id, and next object id. The caller may inspect the
--- manifest, run the rendered atomic leased push with its own Git
--- authentication, fetch the board refs, and ask `refresh` to confirm
--- and clean the staging ref. No implicit network operation lives
--- here; explicit execution is a thin opt-in around the exact argv
--- returned to the caller.
local child = require("cosmic.child")
local codec = require("cosmic.codec")
local rand = require("cosmic.rand")
local gitobj = require("_work.gitobj")
local refs = require("_work.refs")

local VERSION < const > = "gitboard-prepared-v1"
local PREFIX < const > = "refs/gitboard/prepared/"

local record Update
  ref: string
  expected: string
  next: string
end

local record Transaction
  id: string
  staging_ref: string
  manifest: string
  updates: {Update}
end

local enum RefreshState
  "confirmed"
  "pending"
  "lost-race"
end

local record RefreshResult
  transaction: Transaction
  state: RefreshState
  detail: string
  quarantine_ref: string
end

local function valid_sha(sha: string): boolean
  return sha ~= nil and #sha == 40 and sha:match("^[0-9a-f]+$") ~= nil
end

local function valid_target(ref: string): boolean
  return ref:match("^refs/heads/items/[%w_%-]+$") ~= nil
  or ref:match("^refs/heads/ended/[%w_%-]+$") ~= nil
  or ref:match("^refs/heads/board/[%w_%-]+$") ~= nil
  or ref:match("^refs/heads/claim%-batches/[%w_%-]+$") ~= nil
end

--- Canonical manifest bytes. Sorting makes the transaction independent
--- of caller map/table traversal order and duplicate targets are
--- rejected rather than assigned accidental last-writer semantics.
local function encode(updates: {Update}): string | nil, string
  if #updates == 0 then
    return nil, "a prepared transaction must update at least one ref"
  end
  local sorted: {Update} = {}
  local seen: {string: boolean} = {}
  for _, u in ipairs(updates) do
    if not valid_target(u.ref) then
      return nil, ("not a board ref: %s"):format(tostring(u.ref))
    end
    if not valid_sha(u.expected) or not valid_sha(u.next)
    or u.next == refs.ZERO_SHA then
      return nil, ("bad expected/next object id for %s"):format(u.ref)
    end
    if seen[u.ref] then
      return nil, ("duplicate update for %s"):format(u.ref)
    end
    seen[u.ref] = true
    sorted[#sorted + 1] = {
      ref = u.ref, expected = u.expected, next = u.next,
    }
  end
  table.sort(sorted, function(a: Update, b: Update): boolean
      return a.ref < b.ref
    end)
  local lines: {string} = {VERSION, ""}
  for _, u in ipairs(sorted) do
    lines[#lines + 1] = ("%s %s %s"):format(u.expected, u.next, u.ref)
  end
  return table.concat(lines, "\n") .. "\n", ""
end

local function decode(content: string): {Update} | nil, string
  local first, rest = content:match("^([^\n]+)\n\n(.*)$")
  if first ~= VERSION then
    return nil, "not a supported prepared transaction manifest"
  end
  local out: {Update} = {}
  for line in rest:gmatch("([^\n]+)") do
    local expected, next_sha, ref = line:match("^(%S+) (%S+) (%S+)$")
    if expected == nil then
      return nil, ("malformed prepared update: %s"):format(line)
    end
    out[#out + 1] = {ref = ref, expected = expected, next = next_sha}
  end
  local canonical, err = encode(out)
  if canonical == nil then
    return nil, err
  end
  if canonical ~= content then
    return nil, "prepared transaction manifest is not canonical"
  end
  return out, ""
end

local function read_transaction(root: string,
    staging_ref: string): Transaction | nil, string
  if staging_ref:sub(1, #PREFIX) ~= PREFIX then
    return nil, ("not a prepared transaction ref: %s"):format(staging_ref)
  end
  -- Contents and the later CAS must name the same immutable snapshot, even
  -- when another process replaces the staging ref while objects are loaded.
  local manifest, merr = refs.read_ref(root, staging_ref)
  if manifest == nil or manifest == refs.ZERO_SHA then
    return nil, merr ~= "" and merr or "prepared transaction ref disappeared"
  end
  local got, err = gitobj.cat_file_batch(root,
    {manifest, manifest .. ":manifest"})
  if got == nil then
    return nil, err
  end
  local commit = got[manifest]
  local blob = got[manifest .. ":manifest"]
  if commit == nil or commit.otype ~= "commit"
  or blob == nil or blob.otype ~= "blob" then
    return nil, ("unreadable prepared transaction: %s"):format(staging_ref)
  end
  local updates, derr = decode(blob.content)
  if updates == nil then
    return nil, derr
  end
  return {id = staging_ref:sub(#PREFIX + 1), staging_ref = staging_ref,
    manifest = manifest, updates = updates}, ""
end

local function prepare(root: string, updates: {Update},
    message?: string): Transaction | nil, string
  local content, err = encode(updates)
  if content == nil then
    return nil, err
  end
  -- The manifest ref is also the reachability root for every staged
  -- successor. Parent each unique next commit so an aggressive GC
  -- cannot prune work while the caller is offline between prepare and
  -- publication. `decode` returns the canonical ref-sorted order, so
  -- parent ordering (and therefore the manifest commit id) is stable.
  local canonical_updates, uerr = decode(content)
  if canonical_updates == nil then
    return nil, uerr
  end
  local parents: {string} = {}
  local parent_seen: {string: boolean} = {}
  for _, u in ipairs(canonical_updates) do
    if not parent_seen[u.next] then
      parent_seen[u.next] = true
      parents[#parents + 1] = u.next
    end
  end
  local blob, berr = gitobj.hash_object_write(root, content)
  if blob == nil then
    return nil, berr
  end
  local tree, terr = gitobj.mktree_write(root, {
      {mode = "100644", otype = "blob", sha = blob, name = "manifest"},
    })
  if tree == nil then
    return nil, terr
  end
  local commit, cerr = gitobj.commit_tree(root, {
      tree = tree, parents = parents, message = message or "prepare board transaction",
      author_name = "gitboard", author_email = "gitboard@board",
      committer_name = "gitboard", committer_email = "gitboard@board",
    })
  if commit == nil then
    return nil, cerr
  end
  -- The manifest object is deterministic, but its staging receipt must be
  -- per preparation. Two processes may prepare identical updates; sharing a
  -- ref would let one confirmation delete the other's receipt mid-operation.
  local staging_ref = PREFIX .. commit .. "-" .. codec.encode_hex(rand.bytes(8))
  local moved, merr = refs.update_ref(root, staging_ref, commit, refs.ZERO_SHA)
  if not moved then
    return nil, merr
  end
  return read_transaction(root, staging_ref)
end

local function list(root: string): {Transaction} | nil, string
  local found, err = refs.for_each_ref(root, {PREFIX})
  if found == nil then
    return nil, err
  end
  local out: {Transaction} = {}
  for _, e in ipairs(found) do
    local tx, terr = read_transaction(root, e.refname)
    if tx == nil then
      -- Another process may have confirmed and removed this receipt after
      -- our ref snapshot. A vanished receipt is already clean, not damage.
      local observed, oerr = refs.read_ref(root, e.refname)
      if observed == nil then return nil, oerr end
      if observed ~= refs.ZERO_SHA then return nil, terr end
    else
      out[#out + 1] = tx
    end
  end
  return out, ""
end

--- Exact argv for durable publication. The explicit object-id source
--- means canonical local heads never have to move before publication.
--- Every ref is leased and `--atomic` is unconditional; there is no
--- sequential publication mode outside a separate repair procedure.
local function push_argv(tx: Transaction, remote?: string): {string}
  local argv: {string} = {"git", "push", "--atomic"}
  for _, u in ipairs(tx.updates) do
    local expected = u.expected
    if expected == refs.ZERO_SHA then
      expected = ""
    end
    argv[#argv + 1] = ("--force-with-lease=%s:%s"):format(u.ref, expected)
  end
  argv[#argv + 1] = remote or "origin"
  for _, u in ipairs(tx.updates) do
    argv[#argv + 1] = ("%s:%s"):format(u.next, u.ref)
  end
  return argv
end

--- Exact argv the caller runs before `refresh`. Refs land only in the
--- remote-tracking namespace; no local board head is overwritten.
local function fetch_argv(remote?: string): {string}
  local name = remote or "origin"
  return {"git", "fetch", "--atomic", "--prune", name,
    "+refs/heads/items/*:refs/remotes/" .. name .. "/items/*",
    "+refs/heads/ended/*:refs/remotes/" .. name .. "/ended/*",
    "+refs/heads/board/*:refs/remotes/" .. name .. "/board/*",
    "+refs/heads/claim-batches/*:refs/remotes/" .. name
    .. "/claim-batches/*"}
end

--- Explicit opt-in transport execution. This reads no credential and
--- manages no authentication: ordinary Git resolves credentials from
--- the caller's environment/configuration. Default callers use
--- `push_argv`/`fetch_argv` and execute them themselves.
local function execute(root: string, argv: {string}): boolean, string
  local r, err = child.run(argv, {cwd = root})
  if r == nil then
    return false, err
  end
  if not r.ok then
    local detail = (r.stderr or r.stdout):gsub("%s+$", "")
    return false, detail
  end
  return true, ""
end

local function remove(root: string, tx: Transaction): boolean, string
  local removed, err = refs.update_refs_atomic(root, {{ref = tx.staging_ref,
        expected = tx.manifest, next = refs.ZERO_SHA}})
  if removed then return true, "" end
  -- Confirmation cleanup is cooperative: another process refreshing the same
  -- repository may have removed this exact receipt first.
  local observed, oerr = refs.read_ref(root, tx.staging_ref)
  if observed == nil then return false, oerr end
  if observed == refs.ZERO_SHA then return true, "" end
  return false, err
end

--- Preserve a stale plan without leaving it selectable for publication.
local function retire(root: string, tx: Transaction,
    witness: refs.RefCheck): string, string
  local destination = "refs/gitboard/quarantined/lost-race/" .. tx.id
  local before, berr = refs.read_ref(root, destination)
  if before == nil then return "", berr end
  if before ~= refs.ZERO_SHA and before ~= tx.manifest then
    return "", "quarantine destination names a different manifest: " .. destination
  end
  local moved, err = refs.update_refs_atomic(root, {
      {ref = destination, expected = before, next = tx.manifest},
      {ref = tx.staging_ref, expected = tx.manifest, next = refs.ZERO_SHA},
    }, {witness})
  if moved then return destination, "" end
  -- Only another complete retirement of this exact manifest is success.
  local source, serr = refs.read_ref(root, tx.staging_ref)
  if source == nil then return "", serr end
  local after, aerr = refs.read_ref(root, destination)
  if after == nil then return "", aerr end
  if source == refs.ZERO_SHA and after == tx.manifest then
    return destination, ""
  end
  return "", err
end

--- Compare prepared transactions with state the CALLER already
--- fetched. Confirmed manifests are cleaned automatically. A target
--- outside expected/next is a lost race; verified nonzero conflicts
--- quarantine the receipt for diagnosis. Missing observations remain
--- staged. This function performs no fetch or publication retry.
local function refresh(root: string, remote?: string): {RefreshResult} | nil, string
  local pending, err = list(root)
  if pending == nil then
    return nil, err
  end
  local out: {RefreshResult} = {}
  for _, tx in ipairs(pending) do
    local state: RefreshState = "confirmed"
    local detail = "all fetched refs match the prepared transaction"
    local witness: refs.RefCheck = {ref = "", expected = ""}
    for _, u in ipairs(tx.updates) do
      local observed_ref = refs.canonical_ref(root, u.ref, remote)
      if observed_ref == nil then
        return nil, "could not map prepared ref " .. u.ref
      end
      local observed, rerr = refs.read_ref(root, observed_ref)
      if observed == nil then
        return nil, rerr
      end
      if observed ~= u.next then
        if observed ~= u.expected then
          if state ~= "lost-race" then
            detail = ("%s names %s, expected %s or %s"):format(
              observed_ref, observed, u.expected, u.next)
          end
          state = "lost-race"
          if observed ~= refs.ZERO_SHA
          and (witness.ref == "" or observed_ref < witness.ref) then
            witness = {ref = observed_ref, expected = observed}
          end
        elseif state ~= "lost-race" then
          state = "pending"
          detail = ("%s still names the expected object"):format(observed_ref)
        end
      end
    end
    local quarantine_ref = ""
    if state == "confirmed" then
      local cleaned, cerr = remove(root, tx)
      if not cleaned then
        return nil, cerr
      end
    elseif state == "lost-race" and witness.ref ~= ""
    and not refs.has_overlay(root) then
      local retired, rerr = retire(root, tx, witness)
      if retired == "" then return nil, rerr end
      quarantine_ref = retired
      detail = detail .. "; quarantined at " .. retired
    end
    out[#out + 1] = {transaction = tx, state = state, detail = detail,
      quarantine_ref = quarantine_ref}
  end
  return out, ""
end

--- Local-only publication uses the same manifest but promotes every
--- target in one local CAS transaction, then runs the ordinary
--- confirmation/cleanup pass. It exists for tests, simulations and
--- migrations; it is never selected implicitly for remote boards.
local function promote_local(root: string, tx: Transaction): boolean, string
  if refs.board_mode(root) ~= "local" then
    return false, "local promotion is allowed only in gitboard.mode=local"
  end
  local moves: {refs.RefUpdate} = {}
  for _, u in ipairs(tx.updates) do
    moves[#moves + 1] = {ref = u.ref, expected = u.expected, next = u.next}
  end
  local ok, err = refs.update_refs_atomic(root, moves)
  if not ok then
    return false, "lost race while promoting local transaction: " .. err
  end
  local results, rerr = refresh(root)
  if results == nil then
    return false, rerr
  end
  for _, result in ipairs(results) do
    if result.transaction.staging_ref == tx.staging_ref then
      return result.state == "confirmed", result.detail
    end
  end
  return true, ""
end

local record prepared
  type Update = Update
  type Transaction = Transaction
  type RefreshResult = RefreshResult
  prepare: function(root: string, updates: {Update},
  message?: string): Transaction | nil, string
  load: function(root: string, staging_ref: string): Transaction | nil, string
  list: function(root: string): {Transaction} | nil, string
  push_argv: function(tx: Transaction, remote?: string): {string}
  fetch_argv: function(remote?: string): {string}
  execute: function(root: string, argv: {string}): boolean, string
  refresh: function(root: string, remote?: string): {RefreshResult} | nil, string
  promote_local: function(root: string, tx: Transaction): boolean, string
end

local M: prepared = {
  prepare = prepare,
  load = read_transaction,
  list = list,
  push_argv = push_argv,
  fetch_argv = fetch_argv,
  execute = execute,
  refresh = refresh,
  promote_local = promote_local,
}

return M
