--- Construct and persist immutable single-head connector execution plans.
--- Planning validates both the inherited archive and the archive after adding
--- the new non-thin pack. Saved plans are canonical literals sealed by SHA-256 and
--- published with create-once filesystem semantics.
local codec = require("cosmic.codec")
local fd = require("cosmic.fd")
local fs = require("cosmic.fs")
local hash = require("cosmic.hash")
local rand = require("cosmic.rand")
local calls = require("_work.singlehead_calls")
local git = require("_work.singlehead_git")
local literal_codec = require("_work.singlehead_literal")
local objects = require("_work.singlehead_objects")
local transaction = require("_work.singlehead_transaction")

local type Plan = calls.Plan
local type TreeElement = calls.TreeElement

local record Summary
  status: string
  calls: integer
  repository: string
  branch: string
  transaction_sha: string
  tree_content_bytes: integer
end

local record HeadStatus
  head: string
  repository: string
  branch: string
  refs: {string: string}
  packs: integer
  publication_status: string
end

local function empty_elements(): {TreeElement}
  return literal_codec.sequence() as {TreeElement} -- cast: empty wire sequence
end

local function empty_calls(): {calls.Call}
  return literal_codec.sequence() as {calls.Call} -- cast: empty wire sequence
end

local function copied_checks(checks?: {string: string}): {string: string} | nil, string
  local out: {string: string} = {}
  for ref, sha in pairs(checks or {}) do
    local valid_ref, rerr = objects.checked_ref(ref)
    if valid_ref == nil then return nil, rerr end
    local valid_sha, serr = objects.checked_sha(sha, true)
    if valid_sha == nil then return nil, serr end
    out[valid_ref] = valid_sha
  end
  return out, ""
end

local function receipt_digest(transaction_sha: string,
    updates: {objects.Update}, checks: {string: string}): string | nil, string
  local value, err = objects.canonical({transaction_sha = transaction_sha,
      updates = updates, checks = checks})
  if value == nil then return nil, err end
  return objects.sha256(value), ""
end

local function roots(refs: {string: string}): {string}
  local seen: {string: boolean} = {}
  local out: {string} = {}
  for _, sha in pairs(refs) do seen[sha] = true end
  for sha in pairs(seen) do out[#out + 1] = sha end
  table.sort(out)
  return out
end

local function build(source: string, envelope: string, head: string,
    txid: string, raw_updates: {objects.Update}, repository: string,
    branch: string, transaction_sha: string, source_identity?: {string: any},
    bootstrap?: boolean, raw_checks?: {string: string},
    now?: integer): Plan | nil, string
  local exact_head, herr = objects.checked_sha(head, false)
  if exact_head == nil then return nil, herr end
  local exact_tx, terr = objects.checked_sha(transaction_sha, false)
  if exact_tx == nil then return nil, terr end
  local bound_repository, rerr = objects.checked_repository(repository)
  if bound_repository == nil then return nil, rerr end
  local bound_branch, berr = objects.checked_branch(branch)
  if bound_branch == nil then return nil, berr end
  local complete, cerr = objects.source_is_complete(source)
  if not complete then return nil, cerr end
  local updates, uerr = objects.checked_updates(raw_updates)
  if updates == nil then return nil, uerr end
  local checks, cherr = copied_checks(raw_checks)
  if checks == nil then return nil, cherr end
  if #txid < 1 or #txid > 160 or txid:match("^[A-Za-z0-9_-]+$") == nil then
    return nil, "invalid transaction ID"
  end

  local state: objects.State
  local inherited: {string}
  if bootstrap then
    local ok, existing, lerr = git.probe(envelope, {"ls-tree", head, "--", "gitboard"})
    if not ok then return nil, lerr end
    if existing ~= "" then return nil, "bootstrap cannot replace an existing envelope" end
    state = {format = objects.FORMAT, repository = bound_repository,
      branch = bound_branch, refs = {},
      packs = literal_codec.sequence() as {objects.PackDescriptor}, -- cast: empty wire sequence
      receipts = {}}
    inherited = {}
  else
    local archive, aerr = objects.read_validated_archive(envelope, exact_head,
      bound_repository, bound_branch)
    if archive == nil then return nil, aerr end
    state, inherited = archive.state, archive.packs
  end
  local digest, derr = receipt_digest(exact_tx, updates, checks)
  if digest == nil then return nil, derr end
  local prior = state.receipts[txid]
  if prior ~= nil then
    if prior ~= digest then return nil, "transaction ID reused for different contents" end
    local confirmed: Plan = {plan_format = calls.PLAN_FORMAT, status = "confirmed",
      expected_head = "", head = exact_head, repository = bound_repository,
      branch = bound_branch, transaction = txid, transaction_sha = exact_tx,
      receipt_digest = digest, source = source_identity or {}, publish_by = 0,
      base_tree_sha = "", tree_elements = empty_elements(), message = "",
      calls = empty_calls()}
    return confirmed, ""
  end
  for _, update in ipairs(updates) do
    if (state.refs[update.ref] or objects.ZERO) ~= update.expected then
      return nil, "LOST_RACE: " .. update.ref
    end
  end
  for ref, expected in pairs(checks) do
    if (state.refs[ref] or objects.ZERO) ~= expected then return nil, "LOST_RACE: " .. ref end
  end
  local deadline = 0
  if not bootstrap then
    local claim_time, clerr = transaction.claim_deadline(source, updates)
    if claim_time == nil then return nil, clerr end
    deadline = claim_time
    if deadline > 0 and (now or os.time()) >= deadline then
      return nil, "prepared claim batch expired before publication"
    end
  end
  local revisions, seen = {}, {}
  for _, update in ipairs(updates) do
    local is_commit, _out, typeerr = git.probe(source,
      {"cat-file", "-e", update.next .. "^{commit}"})
    if not is_commit then return nil, "board target must be a commit: " .. typeerr end
    if not seen[update.next] then seen[update.next] = true; revisions[#revisions + 1] = update.next end
  end
  table.sort(revisions)
  for _, sha in ipairs(roots(state.refs)) do
    local exists = git.probe(source, {"cat-file", "-e", sha})
    if exists then revisions[#revisions + 1] = "^" .. sha end
  end
  local packed, perr = objects.pack_objects(source, revisions)
  if packed == nil then return nil, perr end
  local pack_id = objects.sha256(packed)
  local elements: {TreeElement} = {}
  local known = false
  for _, descriptor in ipairs(state.packs) do
    if descriptor.sha256 == pack_id then known = true end
  end
  if not known then
    local chunks = (#packed + objects.PACK_CHUNK_BYTES - 1) // objects.PACK_CHUNK_BYTES
    state.packs[#state.packs + 1] = {sha256 = pack_id, chunks = chunks}
    for i = 0, chunks - 1 do
      local first = i * objects.PACK_CHUNK_BYTES + 1
      local chunk = packed:sub(first, first + objects.PACK_CHUNK_BYTES - 1)
      elements[#elements + 1] = {path = objects.pack_path(pack_id, i),
        mode = "100644", otype = "blob", content = codec.encode_base64(chunk) .. "\n"}
    end
  end
  for _, update in ipairs(updates) do state.refs[update.ref] = update.next end
  state.receipts[txid] = digest
  local all_packs: {string} = {}
  for _, bytes in ipairs(inherited) do all_packs[#all_packs + 1] = bytes end
  all_packs[#all_packs + 1] = packed
  local valid, verr = objects.validate_object_graph(all_packs, roots(state.refs))
  if not valid then return nil, verr end
  local state_literal, serr = objects.encode_state(state)
  if state_literal == nil then return nil, serr end
  elements[#elements + 1] = {path = objects.STATE_PATH, mode = "100644",
    otype = "blob", content = state_literal}
  local base_tree, treeerr = objects.read_commit_tree(envelope, exact_head)
  if base_tree == nil then return nil, treeerr end
  local plan: Plan = {plan_format = calls.PLAN_FORMAT, status = "ready",
    expected_head = exact_head, head = "", repository = bound_repository,
    branch = bound_branch, transaction = txid, transaction_sha = exact_tx,
    receipt_digest = digest, source = source_identity or {}, publish_by = deadline,
    base_tree_sha = base_tree, tree_elements = elements,
    message = "gitboard envelope " .. txid, calls = empty_calls()}
  local rendered, rendererr = calls.render(plan)
  if rendered == nil then return nil, rendererr end
  plan.calls = rendered
  local plan_ok, planerr = calls.validate(plan)
  if not plan_ok then return nil, planerr end
  return plan, ""
end

local function build_transaction(source: string, envelope: string, head: string,
    staging_ref: string, repository: string, branch: string,
    checks?: {string: string}, now?: integer): Plan | nil, string
  local frozen, err = transaction.inspect(source, staging_ref, repository, branch)
  if frozen == nil then return nil, err end
  return build(source, envelope, head, frozen.transaction_sha, frozen.updates,
    frozen.source.repository, frozen.source.branch, frozen.transaction_sha,
    frozen.source as {string: any}, -- cast: Binding record serialized as a literal table
    false, checks, now)
end

local function build_seed(source: string, envelope: string, head: string,
    prefix: string, repository: string, branch: string,
    now?: integer): Plan | nil, string
  local snapshot, err = objects.snapshot(source, prefix)
  if snapshot == nil then return nil, err end
  local canonical, cerr = objects.canonical(snapshot)
  if canonical == nil then return nil, cerr end
  local updates: {objects.Update} = {}
  local names: {string} = {}
  for ref in pairs(snapshot) do names[#names + 1] = ref end
  table.sort(names)
  for _, ref in ipairs(names) do
    updates[#updates + 1] = {ref = ref, expected = objects.ZERO, next = snapshot[ref]}
  end
  local snapshot_digest = objects.sha256(canonical)
  local transaction_sha = codec.encode_hex(hash.digest("sha1", "gitboard seed\0" .. canonical))
  return build(source, envelope, head, "seed-" .. snapshot_digest, updates,
    repository, branch, transaction_sha, {}, true, nil, now)
end

local function write_all(handle: fd.Handle, text: string): boolean, string
  local offset = 1
  while offset <= #text do
    local count, err = handle:write(text:sub(offset))
    if count == nil or count == 0 then return false, err ~= "" and err or "short write" end
    offset = offset + count
  end
  return handle:sync()
end

local function save(path: string, plan: Plan): boolean, string
  local ok, err = calls.validate(plan)
  if not ok then return false, err end
  local wire = calls.wire_value(plan)
  local payload, perr = literal_codec.encode(wire)
  if payload == nil then return false, perr end
  local wrapper = {format = calls.PLAN_FORMAT, sha256 = objects.sha256(payload), plan = wire}
  local sealed, serr = literal_codec.encode(wrapper)
  if sealed == nil then return false, serr end
  local made, merr = fs.make_dirs(fs.dirname(path), fs.octal("700"))
  if not made then return false, merr end
  local temporary = fs.join(fs.dirname(path), "." .. fs.basename(path) .. "." .. rand.token())
  local handle, herr = fd.open(temporary,
    fd.O_WRONLY | fd.O_CREAT | fd.O_EXCL | fd.O_NOFOLLOW, fs.octal("400"))
  if handle == nil then return false, herr end
  local written, werr = write_all(handle, sealed)
  local closed, closeerr = handle:close()
  if not written or not closed then
    local _removed, _remove_err = fs.remove(temporary)
    return false, not written and werr or closeerr
  end
  local linked, lerr = fs.link(temporary, path)
  local removed, rmerr = fs.remove(temporary)
  if not removed then return false, "saved plan temporary cleanup failed: " .. rmerr end
  if not linked then
    if fs.is_present(path) then return false, "saved plan already exists: " .. path end
    return false, lerr
  end
  local directory, derr = fd.open(fs.dirname(path), fd.O_RDONLY | fd.O_DIRECTORY)
  if directory == nil then return false, derr end
  local synced, dserr = directory:sync()
  local dclosed, dcerr = directory:close()
  if not synced then return false, dserr end
  if not dclosed then return false, dcerr end
  return true, ""
end

local function as_string(value: any): string | nil
  return value is string and value or nil
end

local function load_plan(path: string): Plan | nil, string
  local raw, rerr = fs.read(path)
  if raw == nil then return nil, "cannot read saved plan: " .. rerr end
  local wrapper, parse_err = literal_codec.decode_object(raw)
  if wrapper == nil then return nil, "invalid saved plan: " .. parse_err end
  local recoded = literal_codec.encode(wrapper)
  if recoded == nil or recoded ~= raw then return nil, "saved plan is not canonical literal" end
  local wrapper_format, raw_plan, wrapper_sha = wrapper.format, wrapper.plan, wrapper.sha256
  if wrapper_format ~= calls.PLAN_FORMAT then return nil, "unsupported saved plan envelope" end
  if not (raw_plan is {string: any}) then return nil, "unsupported saved plan envelope" end
  if not (wrapper_sha is string) then return nil, "unsupported saved plan envelope" end
  local payload, perr = literal_codec.encode(raw_plan)
  if payload == nil then return nil, perr end
  if objects.sha256(payload) ~= wrapper_sha then return nil, "saved plan integrity check failed" end
  local value = raw_plan as {string: any} -- cast: narrowed decoded plan object
  local elements: {TreeElement} = {}
  local raw_elements = value.tree_elements
  if not (raw_elements is {any}) then return nil, "saved plan tree is malformed" end
  for _, raw_element in ipairs(raw_elements) do
    if not (raw_element is {string: any}) then return nil, "saved plan tree is malformed" end
    local path_value, mode, otype, content = raw_element.path, raw_element.mode,
    raw_element["type"], raw_element.content
    if not (path_value is string and mode is string and otype is string and content is string) then
      return nil, "saved plan tree is malformed"
    end
    elements[#elements + 1] = {path = path_value, mode = mode, otype = otype, content = content}
  end
  local decoded_calls: {calls.Call} = {}
  local raw_calls = value.calls
  if not (raw_calls is {any}) then return nil, "saved plan calls are malformed" end
  for _, raw_call in ipairs(raw_calls) do
    if not (raw_call is {string: any}) then return nil, "saved plan calls are malformed" end
    local arguments, id, tool = raw_call.arguments, raw_call.id, raw_call.tool
    if not (arguments is {string: any}) or not (id is string) or not (tool is string) then
      return nil, "saved plan calls are malformed"
    end
    local guard: calls.Guard | nil = nil
    local raw_guard = raw_call.guard
    if raw_guard ~= nil then
      if not (raw_guard is {string: any}) then return nil, "saved plan guard is malformed" end
      local publish_by, rule = raw_guard.publish_by, raw_guard.rule
      if not (publish_by is integer) or not (rule is string) then
        return nil, "saved plan guard is malformed"
      end
      guard = {publish_by = publish_by, rule = rule}
    end
    decoded_calls[#decoded_calls + 1] = {id = id, tool = tool,
      arguments = arguments, guard = guard}
  end
  local source = value.source
  if not (source is {string: any}) then return nil, "saved plan source binding is malformed" end
  local raw_publish_by = value.publish_by
  local publish_by = raw_publish_by is integer and raw_publish_by or -1
  local plan: Plan = {
    plan_format = as_string(value.plan_format) or "", status = as_string(value.status) or "",
    expected_head = as_string(value.expected_head) or "", head = as_string(value.head) or "",
    repository = as_string(value.repository) or "", branch = as_string(value.branch) or "",
    transaction = as_string(value.transaction) or "",
    transaction_sha = as_string(value.transaction_sha) or "",
    receipt_digest = as_string(value.receipt_digest) or "", source = source,
    publish_by = publish_by,
    base_tree_sha = as_string(value.base_tree_sha) or "",
    tree_elements = elements, message = as_string(value.message) or "", calls = decoded_calls,
  }
  local valid, verr = calls.validate(plan)
  if not valid then return nil, verr end
  return plan, ""
end

local function summary(plan: Plan): Summary | nil, string
  local ok, err = calls.validate(plan)
  if not ok then return nil, err end
  local bytes = 0
  for _, element in ipairs(plan.tree_elements) do bytes = bytes + #element.content end
  return {status = plan.status, calls = #plan.calls, repository = plan.repository,
    branch = plan.branch, transaction_sha = plan.transaction_sha,
    tree_content_bytes = bytes}, ""
end

local function inspect_head(envelope: string, head: string,
    plan?: Plan): HeadStatus | nil, string
  local repository: string | nil = nil
  local branch: string | nil = nil
  if plan ~= nil then
    local ok, err = calls.validate(plan)
    if not ok then return nil, err end
    repository, branch = plan.repository, plan.branch
  end
  local archive, err = objects.read_validated_archive(envelope, head, repository, branch)
  if archive == nil then return nil, err end
  local status = "uninspected"
  if plan ~= nil then
    local observed = archive.state.receipts[plan.transaction]
    status = observed == plan.receipt_digest and "confirmed"
    or observed ~= nil and "conflict" or "pending"
  end
  return {head = head, repository = archive.state.repository,
    branch = archive.state.branch, refs = archive.state.refs,
    packs = #archive.state.packs, publication_status = status}, ""
end

local function local_candidate(envelope: string, plan: Plan,
    now?: integer): string | nil, string
  local ok, err = calls.validate(plan)
  if not ok then return nil, err end
  if plan.status ~= "ready" then return nil, "plan is already confirmed" end
  if plan.publish_by > 0 and (now or os.time()) >= plan.publish_by then
    return nil, "prepared claim batch expired before publication"
  end
  local entries: {objects.TreeElement} = {}
  for _, element in ipairs(plan.tree_elements) do entries[#entries + 1] = element end
  local tree, terr = objects.make_tree(envelope, entries, plan.base_tree_sha)
  if tree == nil then return nil, terr end
  return objects.make_commit(envelope, tree, plan.message, plan.expected_head)
end

local record singlehead_plan
  type Plan = calls.Plan
  type Summary = Summary
  type HeadStatus = HeadStatus
  build: function(source: string, envelope: string, head: string,
  txid: string, updates: {objects.Update}, repository: string, branch: string,
  transaction_sha: string, source_identity?: {string: any}, bootstrap?: boolean,
  checks?: {string: string}, now?: integer): Plan | nil, string
  build_transaction: function(source: string, envelope: string, head: string,
  staging_ref: string, repository: string, branch: string,
  checks?: {string: string}, now?: integer): Plan | nil, string
  build_seed: function(source: string, envelope: string, head: string,
  prefix: string, repository: string, branch: string,
  now?: integer): Plan | nil, string
  save: function(path: string, plan: Plan): boolean, string
  load: function(path: string): Plan | nil, string
  summary: function(plan: Plan): Summary | nil, string
  inspect_head: function(envelope: string, head: string,
  plan?: Plan): HeadStatus | nil, string
  local_candidate: function(envelope: string, plan: Plan,
  now?: integer): string | nil, string
end

local M: singlehead_plan = {build = build, build_transaction = build_transaction,
  build_seed = build_seed, save = save, load = load_plan, summary = summary,
  inspect_head = inspect_head, local_candidate = local_candidate}
return M
