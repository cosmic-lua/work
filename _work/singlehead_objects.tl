--- Native object archive for the connector-backed single-head transport.
local codec = require("cosmic.codec")
local fs = require("cosmic.fs")
local hash = require("cosmic.hash")
local git = require("_work.singlehead_git")
local wire = require("_work.singlehead_literal")

local ZERO < const > = "0000000000000000000000000000000000000000"
local FORMAT < const > = "gitboard-single-head-v2"
local STATE_PATH < const > = "gitboard/state.literal"
local PACK_CHUNK_BYTES < const > = 96 * 1024
local record Update ref: string expected: string next: string end
local record PackDescriptor sha256: string chunks: integer end
local record State
  format: string
  repository: string
  branch: string
  refs: {string: string}
  packs: {PackDescriptor}
  receipts: {string: string}
end
local record Archive
  state: State
  packs: {string}
end
local record TreeElement path: string mode: string otype: string content: string end
local function canonical(value: any): string | nil, string
  return wire.encode(value)
end
local function sha256(bytes: string): string
  return hash.sha256_hex(bytes)
end
local function checked_repository(value: any): string | nil, string
  if not (value is string)
  or value:match("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$") == nil then
    return nil, "repository must be an owner/name GitHub slug"
  end
  return value:lower(), ""
end
local function checked_branch(value: any): string | nil, string
  if not (value is string) or value == "" or value:sub(1, 5) == "refs/" then
    return nil, "branch must be a branch name, not a ref"
  end
  for _, reserved in ipairs({"items", "ended", "board", "claims", "claim-batches"}) do
    if value == reserved or value:sub(1, #reserved + 1) == reserved .. "/" then
      return nil, "envelope branch collides with a board namespace"
    end
  end
  local ok = git.probe(".", {"check-ref-format", "refs/heads/" .. value})
  if not ok then return nil, "invalid envelope branch" end
  return value, ""
end

local function checked_ref(value: any): string | nil, string
  if not (value is string)
  or (value:match("^refs/heads/items/[A-Za-z0-9_-]+$") == nil
    and value:match("^refs/heads/ended/[A-Za-z0-9_-]+$") == nil
    and value:match("^refs/heads/board/[A-Za-z0-9_-]+$") == nil
    and value:match("^refs/heads/claim%-batches/[A-Za-z0-9_-]+$") == nil) then
    return nil, "not a supported board ref: " .. tostring(value)
  end
  return value, ""
end

local function checked_sha(value: any, allow_zero?: boolean): string | nil, string
  if not (value is string) or #value ~= 40 or value:match("^[0-9a-f]+$") == nil
  or (value == ZERO and not allow_zero) then
    return nil, "not a supported object ID: " .. tostring(value)
  end
  return value, ""
end

local function checked_updates(updates: {Update}): {Update} | nil, string
  if #updates == 0 then return nil, "empty transaction" end
  local out: {Update} = {}
  local seen: {string: boolean} = {}
  for _, update in ipairs(updates) do
    local _, rerr = checked_ref(update.ref)
    if rerr ~= "" then return nil, rerr end
    local _, oerr = checked_sha(update.expected, true)
    if oerr ~= "" then return nil, oerr end
    local _, nerr = checked_sha(update.next)
    if nerr ~= "" then return nil, nerr end
    if seen[update.ref] then return nil, "duplicate transaction target" end
    if update.ref:find("/claim-batches/", 1, true) and update.expected ~= ZERO then
      return nil, "claim batches are append-only"
    end
    seen[update.ref] = true
    out[#out + 1] = {ref = update.ref, expected = update.expected, next = update.next}
  end
  table.sort(out, function(a: Update, b: Update): boolean return a.ref < b.ref end)
  return out, ""
end

local function snapshot(repo: string, prefix: string): {string: string} | nil, string
  if prefix ~= "refs/heads/"
  and (prefix:match("^refs/remotes/[A-Za-z0-9._/-]+/$") == nil
    or prefix:find("..", 1, true)) then
    return nil, "unsupported snapshot prefix"
  end
  local raw, err = git.run(repo,
    {"for-each-ref", "--format=%(refname) %(objectname)", prefix})
  if raw == nil then return nil, err end
  local refs: {string: string} = {}
  for line in raw:gmatch("([^\n]+)") do
    local ref, object = line:match("^(%S+) (%S+)$")
    if ref == nil or ref:sub(1, #prefix) ~= prefix then
      return nil, "malformed snapshot row"
    end
    local target = "refs/heads/" .. ref:sub(#prefix + 1)
    if checked_ref(target) ~= nil then
      local valid, serr = checked_sha(object)
      if valid == nil then return nil, serr end
      refs[target] = valid
    end
  end
  return refs, ""
end

local function pack_path(digest: string, chunk?: integer): string
  return ("gitboard/packs/%s/%06d.pack.b64"):format(digest, chunk or 0)
end

local function exact_keys(value: {string: any}, names: {string}): boolean
  local wanted: {string: boolean} = {}
  for _, name in ipairs(names) do wanted[name] = true end
  local count = 0
  for name in pairs(value) do
    if not wanted[name] then return false end
    count = count + 1
  end
  return count == #names
end

local function state_value(state: State): {string: any}
  local packs = wire.sequence()
  for _, pack in ipairs(state.packs) do
    packs[#packs + 1] = {sha256 = pack.sha256, chunks = pack.chunks}
  end
  return {format = state.format, repository = state.repository,
    branch = state.branch, refs = state.refs, packs = packs, receipts = state.receipts}
end

local function encode_state(state: State): string | nil, string
  return canonical(state_value(state))
end

local function decode_state(raw: string): State | nil, string
  local object, err = wire.decode_object(raw)
  if object == nil then return nil, "invalid envelope state: " .. err end
  local recoded = canonical(object)
  if recoded == nil or recoded ~= raw then
    return nil, "envelope state is not canonical literal"
  end
  if not exact_keys(object, {"format", "repository", "branch", "refs", "packs", "receipts"}) then
    return nil, "invalid envelope state fields"
  end
  if object["format"] ~= FORMAT then
    return nil, "unsupported envelope format: " .. tostring(object["format"])
  end
  local repository, rerr = checked_repository(object["repository"])
  if repository == nil or repository ~= object["repository"] then
    return nil, rerr ~= "" and rerr or "invalid envelope repository binding"
  end
  local branch, berr = checked_branch(object["branch"])
  if branch == nil then return nil, berr end
  local raw_refs, raw_packs, raw_receipts = object["refs"], object["packs"], object["receipts"]
  if not (raw_refs is {string: any}) or not (raw_packs is {any})
  or not (raw_receipts is {string: any}) or wire.is_sequence(raw_refs)
  or not wire.is_sequence(raw_packs) or wire.is_sequence(raw_receipts) then
    return nil, "invalid envelope state shape"
  end
  local refs: {string: string} = {}
  for ref, object_id in pairs(raw_refs) do
    if checked_ref(ref) == nil then return nil, "not a supported board ref: " .. ref end
    local valid, serr = checked_sha(object_id)
    if valid == nil then return nil, serr end
    refs[ref] = valid
  end
  local packs: {PackDescriptor} = {}
  local pack_seen: {string: boolean} = {}
  for _, raw_pack in ipairs(raw_packs) do
    if not (raw_pack is {string: any})
    or not exact_keys(raw_pack, {"sha256", "chunks"}) then
      return nil, "invalid pack descriptor"
    end
    local digest, chunks = raw_pack["sha256"], raw_pack["chunks"]
    if not (digest is string) or #digest ~= 64 or digest:match("^[0-9a-f]+$") == nil
    or not (chunks is integer) or chunks <= 0 then return nil, "invalid pack ID" end
    if pack_seen[digest] then return nil, "duplicate pack" end
    pack_seen[digest] = true
    packs[#packs + 1] = {sha256 = digest, chunks = chunks}
  end
  local receipts: {string: string} = {}
  for txid, digest in pairs(raw_receipts) do
    if txid:match("^[A-Za-z0-9_-]+$") == nil or #txid > 160
    or not (digest is string) or #digest ~= 64
    or digest:match("^[0-9a-f]+$") == nil then return nil, "invalid receipt" end
    receipts[txid] = digest
  end
  return {format = FORMAT, repository = repository, branch = branch,
    refs = refs, packs = packs, receipts = receipts}, ""
end

local function read_state(envelope: string, head: string,
    repository?: string, branch?: string): State | nil, string
  local _, herr = checked_sha(head)
  if herr ~= "" then return nil, herr end
  local raw, err = git.run(envelope, {"show", head .. ":" .. STATE_PATH})
  if raw == nil then
    local legacy = git.probe(envelope, {"cat-file", "-e", head .. ":gitboard/state.json"})
    if legacy then return nil, "unsupported envelope format: gitboard-single-head-v1" end
    return nil, err
  end
  local state, serr = decode_state(raw)
  if state == nil then return nil, serr end
  if repository ~= nil then
    local expected, rerr = checked_repository(repository)
    if expected == nil then return nil, rerr end
    if expected ~= state.repository then return nil, "envelope belongs to a different repository" end
  end
  if branch ~= nil then
    local expected, berr = checked_branch(branch)
    if expected == nil then return nil, berr end
    if expected ~= state.branch then return nil, "envelope belongs to a different branch" end
  end
  return state, ""
end

local function read_pack(envelope: string, head: string,
    descriptor: PackDescriptor): string | nil, string
  local chunks: {string} = {}
  for index = 0, descriptor.chunks - 1 do
    local encoded = git.run(envelope,
      {"show", head .. ":" .. pack_path(descriptor.sha256, index)})
    if encoded == nil then return nil, "corrupt envelope pack: " .. descriptor.sha256 end
    if encoded:sub(-1) ~= "\n" or encoded:find("\n", 1, true) ~= #encoded then
      return nil, "corrupt envelope pack: " .. descriptor.sha256
    end
    local text = encoded:sub(1, -2)
    local decoded = codec.decode_base64(text)
    if decoded == nil or codec.encode_base64(decoded) ~= text then
      return nil, "corrupt envelope pack: " .. descriptor.sha256
    end
    chunks[#chunks + 1] = decoded
  end
  local packed = table.concat(chunks)
  if sha256(packed) ~= descriptor.sha256 then
    return nil, "corrupt envelope pack: " .. descriptor.sha256
  end
  return packed, ""
end

local function index_pack(repo: string, packed: string,
    isolated?: boolean): boolean, string
  local _, err = git.run(repo, {"index-pack", "--stdin", "--strict"}, packed,
    nil, isolated)
  if err ~= "" then return false, err end
  return true, ""
end

local function validate_object_graph(packs: {string}, roots: {string}): boolean, string
  local base = os.getenv("TEST_TMPDIR") or os.getenv("TMPDIR") or "/tmp"
  local temporary, terr = fs.temp_dir(fs.join(base, "gitboard-archive-check-XXXXXX"))
  if temporary == nil then return false, terr end
  local function fail(message: string): boolean, string
    local _ok, _err = fs.remove_all(temporary)
    return false, message
  end
  local _, ierr = git.run(temporary,
    {"init", "--quiet", "--bare", "--object-format=sha1"}, nil, nil, true)
  if ierr ~= "" then return fail(ierr) end
  for _, packed in ipairs(packs) do
    local ok = index_pack(temporary, packed, true)
    if not ok then return fail("corrupt envelope pack structure") end
  end
  local unique: {string: boolean} = {}
  local sorted: {string} = {}
  for _, root in ipairs(roots) do
    local valid, verr = checked_sha(root)
    if valid == nil then return fail(verr) end
    if not unique[root] then unique[root], sorted[#sorted + 1] = true, root end
  end
  table.sort(sorted)
  for _, root in ipairs(sorted) do
    local kind = git.text(temporary, {"cat-file", "-t", root}, nil, nil, true)
    if kind ~= "commit" then return fail("archive lacks board commit: " .. root) end
  end
  if #sorted > 0 then
    local missing, merr = git.run(temporary,
      {"rev-list", "--objects", "--stdin", "--missing=print"},
      table.concat(sorted, "\n") .. "\n", nil, true)
    if missing == nil then return fail("archive object graph is incomplete: " .. merr) end
    for line in missing:gmatch("([^\n]+)") do
      if line:sub(1, 1) == "?" then return fail("archive object graph is incomplete") end
    end
    local args: {string} = {"fsck", "--strict", "--connectivity-only", "--no-dangling"}
    for _, root in ipairs(sorted) do args[#args + 1] = root end
    local _, ferr = git.run(temporary, args, nil, nil, true)
    if ferr ~= "" then return fail("archive object graph is incomplete: " .. ferr) end
  end
  local _ok, _err = fs.remove_all(temporary)
  return true, ""
end

local function read_validated_archive(envelope: string, head: string,
    repository?: string, branch?: string): Archive | nil, string
  local state, err = read_state(envelope, head, repository, branch)
  if state == nil then return nil, err end
  local packs: {string} = {}
  for _, descriptor in ipairs(state.packs) do
    local packed, perr = read_pack(envelope, head, descriptor)
    if packed == nil then return nil, perr end
    packs[#packs + 1] = packed
  end
  local roots: {string} = {}
  for _, object in pairs(state.refs) do roots[#roots + 1] = object end
  local ok, verr = validate_object_graph(packs, roots)
  if not ok then return nil, verr end
  return {state = state, packs = packs}, ""
end

local function source_is_complete(source: string): boolean, string
  local format, ferr = git.text(source, {"rev-parse", "--show-object-format"})
  if format == nil then return false, ferr end
  if format ~= "sha1" then return false, "single-head transport requires SHA-1 objects" end
  local shallow, serr = git.text(source, {"rev-parse", "--is-shallow-repository"})
  if shallow == nil then return false, serr end
  if shallow ~= "false" then return false, "shallow source cannot prove complete object history" end
  local partial, partial_out = git.probe(source,
    {"config", "--get", "extensions.partialClone"})
  if partial and partial_out:gsub("%s+$", "") ~= "" then
    return false, "partial/promisor source cannot prove complete object history"
  end
  local promisor, promisor_out, promisor_err = git.probe(source,
    {"config", "--type=bool", "--get-regexp", "^remote\\..*\\.promisor$"})
  if not promisor and promisor_err ~= "" then return false, "invalid promisor configuration" end
  if promisor then
    for line in promisor_out:gmatch("([^\n]+)") do
      local value = line:match("(%S+)%s*$")
      if value and value:lower() == "true" then
        return false, "partial/promisor source cannot prove complete object history"
      end
    end
  end
  return true, ""
end

local function pack_objects(source: string, revisions: {string}): string | nil, string
  if #revisions == 0 then return nil, "cannot build an empty object pack" end
  local ok, err = source_is_complete(source)
  if not ok then return nil, err end
  return git.run(source, {"pack-objects", "--stdout", "--revs"},
    table.concat(revisions, "\n") .. "\n")
end

local function make_tree(repo: string, elements: {TreeElement},
    base_tree?: string): string | nil, string
  local tempbase = os.getenv("TEST_TMPDIR") or os.getenv("TMPDIR") or "/tmp"
  local temporary, terr = fs.temp_dir(fs.join(tempbase, "gitboard-envelope-index-XXXXXX"))
  if temporary == nil then return nil, terr end
  local set = {GIT_INDEX_FILE = fs.join(temporary, "index")}
  local function fail(message: string): string | nil, string
    local _ok, _err = fs.remove_all(temporary)
    return nil, message
  end
  local args = base_tree and {"read-tree", base_tree} or {"read-tree", "--empty"}
  local _, rerr = git.run(repo, args, nil, set)
  if rerr ~= "" then return fail(rerr) end
  for _, element in ipairs(elements) do
    if element.mode ~= "100644" or element.otype ~= "blob" then
      return fail("unsupported envelope tree element")
    end
    local object, herr = git.text(repo,
      {"hash-object", "-w", "--stdin"}, element.content)
    if object == nil then return fail(herr) end
    local _, uerr = git.run(repo, {"update-index", "--add", "--cacheinfo",
        "100644", object, element.path}, nil, set)
    if uerr ~= "" then return fail(uerr) end
  end
  local tree, werr = git.text(repo, {"write-tree"}, nil, set)
  local _ok, _err = fs.remove_all(temporary)
  if tree == nil then return nil, werr end
  return tree, ""
end

local function make_commit(repo: string, tree: string, message: string,
    parent?: string): string | nil, string
  local args: {string} = {"commit-tree", tree}
  if parent then args[#args + 1] = "-p"; args[#args + 1] = parent end
  local set: {string: string} = {
    GIT_AUTHOR_NAME = "Gitboard POC", GIT_AUTHOR_EMAIL = "poc@board",
    GIT_COMMITTER_NAME = "Gitboard POC", GIT_COMMITTER_EMAIL = "poc@board",
  }
  return git.text(repo, args, message, set)
end

local function read_commit_tree(repo: string, head: string): string | nil, string
  return git.oid(repo, head .. "^{tree}")
end

local function restore(envelope: string, head: string,
    destination: string): State | nil, string
  if fs.is_present(destination) then
    if not fs.is_dir(destination) then return nil, "restore destination must be empty" end
    local found, ferr = fs.find(destination, {recursive = false, include_dirs = true})
    if found == nil then return nil, ferr end
    if #found > 0 then return nil, "restore destination must be empty" end
  end
  local archive, aerr = read_validated_archive(envelope, head)
  if archive == nil then return nil, aerr end
  local parent = fs.dirname(destination)
  local ok, derr = fs.make_dirs(parent)
  if not ok then return nil, derr end
  local temporary, terr = fs.temp_dir(fs.join(parent,
      "." .. fs.basename(destination) .. ".restore-XXXXXX"))
  if temporary == nil then return nil, terr end
  local function fail(message: string): State | nil, string
    local _ok, _err = fs.remove_all(temporary)
    return nil, message
  end
  local _, ierr = git.run(temporary, {"init", "--quiet", "--object-format=sha1"})
  if ierr ~= "" then return fail(ierr) end
  local _, cerr = git.run(temporary, {"config", "gitboard.mode", "local"})
  if cerr ~= "" then return fail(cerr) end
  for _, packed in ipairs(archive.packs) do
    local indexed, perr = index_pack(temporary, packed)
    if not indexed then return fail(perr) end
  end
  local names: {string} = {}
  for ref in pairs(archive.state.refs) do names[#names + 1] = ref end
  table.sort(names)
  local commands: {string} = {"start"}
  for _, ref in ipairs(names) do
    commands[#commands + 1] = ("update %s %s %s"):format(ref, archive.state.refs[ref], ZERO)
  end
  commands[#commands + 1] = "prepare"; commands[#commands + 1] = "commit"
  local _, uerr = git.run(temporary, {"update-ref", "--stdin"},
    table.concat(commands, "\n") .. "\n")
  if uerr ~= "" then return fail(uerr) end
  if fs.is_present(destination) then
    local removed, rerr = fs.remove_dir(destination)
    if not removed then return fail(rerr) end
  end
  local moved, merr = fs.move(temporary, destination)
  if not moved then return fail(merr) end
  return archive.state, ""
end

local record SingleHeadObjects
  ZERO: string
  FORMAT: string
  STATE_PATH: string
  PACK_CHUNK_BYTES: integer
  type Update = Update
  type PackDescriptor = PackDescriptor
  type State = State
  type Archive = Archive
  type TreeElement = TreeElement
  canonical: function(value: any): string | nil, string
  sha256: function(bytes: string): string
  checked_repository: function(value: any): string | nil, string
  checked_branch: function(value: any): string | nil, string
  checked_ref: function(value: any): string | nil, string
  checked_sha: function(value: any, allow_zero?: boolean): string | nil, string
  checked_updates: function(updates: {Update}): {Update} | nil, string
  snapshot: function(repo: string, prefix: string): {string: string} | nil, string
  pack_path: function(digest: string, chunk?: integer): string
  encode_state: function(state: State): string | nil, string
  decode_state: function(raw: string): State | nil, string
  read_state: function(envelope: string, head: string,
  repository?: string, branch?: string): State | nil, string
  read_validated_archive: function(envelope: string, head: string,
  repository?: string, branch?: string): Archive | nil, string
  validate_object_graph: function(packs: {string}, roots: {string}): boolean, string
  source_is_complete: function(source: string): boolean, string
  pack_objects: function(source: string, revisions: {string}): string | nil, string
  index_pack: function(repo: string, packed: string, isolated?: boolean): boolean, string
  make_tree: function(repo: string, elements: {TreeElement},
  base_tree?: string): string | nil, string
  make_commit: function(repo: string, tree: string, message: string,
  parent?: string): string | nil, string
  read_commit_tree: function(repo: string, head: string): string | nil, string
  restore: function(envelope: string, head: string, destination: string): State | nil, string
end

local M: SingleHeadObjects = {
  ZERO = ZERO, FORMAT = FORMAT, STATE_PATH = STATE_PATH, PACK_CHUNK_BYTES = PACK_CHUNK_BYTES,
  canonical = canonical, sha256 = sha256,
  checked_repository = checked_repository, checked_branch = checked_branch,
  checked_ref = checked_ref, checked_sha = checked_sha,
  checked_updates = checked_updates, snapshot = snapshot, pack_path = pack_path,
  encode_state = encode_state, decode_state = decode_state, read_state = read_state,
  read_validated_archive = read_validated_archive,
  validate_object_graph = validate_object_graph,
  source_is_complete = source_is_complete, pack_objects = pack_objects,
  index_pack = index_pack, make_tree = make_tree, make_commit = make_commit,
  read_commit_tree = read_commit_tree, restore = restore,
}
return M
