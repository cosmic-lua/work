--- Offline, restartable migration planning. This module never pushes and never
--- changes the public state or format refs. Activation belongs to a separately
--- verified shell executor, after a complete remote refset and freeze recheck.
local fs = require("cosmic.fs")
local hash = require("cosmic.hash")
local wire = require("_work.singlehead_literal")
local source = require("_work.migrate6_source")
local replay = require("_work.migrate6_replay")
local freeze = require("_work.migrate6_freeze")
local probes = require("_work.migrate6_probes")
local archive = require("_work.migrate6_archive")

local record Checkpoint
  version: string
  repository: string
  snapshot_at: integer
  phase: string
  prefix: string
  sources: {string: string}
  marks: {string: string}
  head: string
  replayed_head: string
  activation: string
  count: integer
  freeze: freeze.Proof
end
local record Options
  prefix: string
  checkpoint: string
  catch_up: boolean
  state_ref: string
  remote: string
  freeze: freeze.Proof
end

--- Whether a decoded checkpoint field is a map whose every value is an object
--- id — the shape the source and marks maps must have before anything trusts one.
--- @param raw any A field from the decoded checkpoint
--- @return boolean True when every value is a full lowercase hex id
local function sha_map(raw: any): boolean
  if not (raw is {string: any}) then return false end
  for _, value in pairs(raw) do
    if not (value is string) or #value ~= 40 or not value:match("^[0-9a-f]+$") then return false end
  end
  return true
end

--- One checkpoint back from disk, every field checked: the version, the two id
--- maps, the phase's own invariants, and the freeze proof when one is bound. A
--- checkpoint is what makes the migration restartable, so a malformed one is
--- refused rather than partially believed.
--- @param path string The checkpoint's path
--- @return Checkpoint | nil The checkpoint
--- @return string Error message
local function read(path: string): Checkpoint | nil, string
  local content, err = fs.read(path)
  if content == nil then return nil, err end
  local raw, rerr = wire.decode_object(content)
  if raw == nil then return nil, rerr end
  local prefix, head, replayed_head = raw.prefix, raw.head, raw.replayed_head
  local activation, count = raw.activation, raw.count
  local repository = raw.repository
  local snapshot_at = raw.snapshot_at
  if raw.version == "migrate6-v1" then return nil, "older migration replay semantics; choose a new checkpoint path and replay again" end
  if raw.version ~= "migrate6-v2" or (raw.phase ~= "frozen" and raw.phase ~= "planned")
  or not (prefix is string) or not sha_map(raw.sources) or not sha_map(raw.marks)
  or not (head is string) or not (replayed_head is string)
  or not (activation is string) or not (count is integer) then
    return nil, "invalid migrate6 checkpoint"
  end
  if not (repository is string) or repository == "" then return nil, "checkpoint lacks repository binding" end
  if not (snapshot_at is integer) or snapshot_at < 1 then return nil, "checkpoint lacks snapshot time" end
  if raw.phase == "planned" and (#head ~= 40 or #activation ~= 40) then
    return nil, "invalid planned migration head"
  end
  if raw.freeze ~= nil then
    local proof, ferr = freeze.decode(raw.freeze)
    if proof == nil then return nil, ferr end
    if proof.prefix ~= prefix then return nil, "freeze proof checkpoint prefix differs" end
    raw.freeze = proof
  end
  return raw as Checkpoint, "" -- cast: literal fields checked above
end

--- Write the checkpoint atomically, so an interrupted run leaves either the
--- previous checkpoint or the new one, never half of either.
--- @param path string The checkpoint's path
--- @param checkpoint Checkpoint The checkpoint to write
--- @return boolean True on success
--- @return string Error message
local function save(path: string, checkpoint: Checkpoint): boolean, string
  local encoded, err = wire.encode(checkpoint)
  if encoded == nil then return false, err end
  return fs.write(path, encoded, {atomic = true})
end

--- Whether the source refs still are what the checkpoint recorded — every name
--- and every tip. Any ref moved, added or removed is named rather than
--- resampled: a migration that re-read its own sources would silently replay a
--- different board than the one it checkpointed.
--- @param root string The source repository
--- @param checkpoint Checkpoint The checkpoint to compare against
--- @return boolean True when the source ref set is identical
--- @return string The drift, ref by ref
local function validate_sources(root: string, checkpoint: Checkpoint): boolean, string
  local actual, err = source.snapshot(root, checkpoint.prefix)
  if actual == nil then return false, err end
  if checkpoint.freeze ~= nil then
    local filtered, ferr = probes.filter(actual, checkpoint.prefix, checkpoint.freeze.probes)
    if filtered == nil then return false, ferr end
    actual = filtered
  end
  return source.compare(checkpoint.sources, actual)
end

--- Whether a drifted source ref may still be replayed: only while the
--- destination's `state` carries no native write past the activation commit.
--- The live head is read from the destination itself and confirmed not to have
--- moved during the check; an absent one refuses, because "no state" is not
--- proof that nothing was written.
--- @param root string The source repository
--- @param checkpoint Checkpoint The checkpoint being resumed
--- @param state_ref string | nil The ref to read the live head from
--- @param remote string | nil The destination remote to confirm against
--- @return boolean True when catch-up may append
--- @return string Why hand reconciliation is required instead
local function validate_catch_up(root: string, checkpoint: Checkpoint,
    state_ref?: string, remote?: string): boolean, string
  local ref = state_ref or (checkpoint.prefix .. "state")
  local selected = remote or ref:match("^refs/remotes/([^/]+)/state$")
  local head = ""
  if selected ~= nil then
    local url, uerr = source.git(root, {"remote", "get-url", "--push", selected})
    if url == nil then return false, uerr end
    local destination = url:gsub("%s+$", "")
    local advertised, aerr = source.git(root, {"ls-remote", "--refs", destination, "refs/heads/state"})
    if advertised == nil then return false, aerr end
    head = advertised:match("^([0-9a-f]+)%s+refs/heads/state\n$") or ""
    if head ~= "" then
      local fetched, ferr = source.git(root, {"fetch", "--no-tags", destination,
          "refs/heads/state:refs/gitboard/migrate6/catchup-state"})
      if fetched == nil then return false, ferr end
      local confirmed, cerr = source.git(root, {"ls-remote", "--refs", destination, "refs/heads/state"})
      if confirmed == nil then return false, cerr end
      if confirmed ~= advertised then return false, "destination state moved during catch-up verification" end
    end
  elseif ref == "refs/heads/state" then
    local actual, err = source.git(root, {"for-each-ref", "--format=%(objectname)", ref})
    if actual == nil then return false, err end
    head = actual:gsub("%s+$", "")
  else return false, "catch-up requires a destination remote for confirmed state verification" end
  if head == "" then return false, "catch-up refuses without a confirmed state head" end
  if head ~= checkpoint.activation then
    local ancestor = source.git(root, {"merge-base", "--is-ancestor", head, checkpoint.activation})
    if ancestor ~= nil then return true, "" end
    local _, drift = validate_sources(root, checkpoint)
    return false, "catch-up refuses after a native state write; hand reconciliation required: " .. drift
  end
  return true, ""
end

--- Plan or resume the migration, locally: snapshot the source refs, refuse a
--- shallow or partial clone, replay every item ref's history into one candidate
--- `state`, and checkpoint all of it. A rerun against an unchanged source
--- reports the same head; a moved source ref refuses unless catch-up is asked
--- for and allowed. Nothing here pushes, and no public ref is touched.
--- @param root string The source repository
--- @param options Options | nil The prefix, checkpoint path, freeze proof and
--- catch-up switch; every field has a default
--- @return Checkpoint | nil The checkpoint, phase "planned" once replayed
--- @return string Error message
local function run(root: string, options?: Options): Checkpoint | nil, string
  local opts = options or {}
  local prefix = opts.prefix or "refs/heads/"
  local identity, iderr = source.git(root, {"rev-parse", "--absolute-git-dir"})
  if identity == nil then return nil, iderr end
  local repository = identity:gsub("%s+$", "")
  local path = fs.absolute_path(opts.checkpoint or fs.join(root, "o/migrate6/checkpoint.literal"))
  local workdir = fs.dirname(path)
  local made, merr = fs.make_dirs(workdir)
  if not made then return nil, merr end
  local snapshot_at = os.time()
  local refs, serr = source.snapshot(root, prefix)
  if refs == nil then return nil, serr end
  if opts.freeze ~= nil then
    local filtered, ferr = probes.filter(refs, prefix, opts.freeze.probes)
    if filtered == nil then return nil, ferr end
    refs = filtered
    local encoded, err = wire.encode(refs)
    if encoded == nil then return nil, err end
    if opts.freeze.prefix ~= prefix or opts.freeze.source_digest ~= hash.sha256_hex(encoded) then
      return nil, "freeze witness source snapshot differs"
    end
  end
  local valid, ierr = source.integrity(root, refs)
  if not valid then return nil, ierr end
  local manifest: probes.Manifest = opts.freeze and opts.freeze.probes or nil
  local archive_text, archive_err = archive.build(refs, prefix, manifest)
  if archive_text == nil then return nil, archive_err end
  local checkpoint: Checkpoint | nil = nil
  if fs.is_present(path) then
    local old, err = read(path)
    if old == nil then return nil, err end
    if old.repository ~= repository then return nil, "checkpoint repository differs" end
    if old.prefix ~= prefix then return nil, "checkpoint source prefix differs" end
    local same, drift = source.compare(old.sources, refs)
    if not same then
      if not opts.catch_up then return nil, drift end
      local safe, e = validate_catch_up(root, old, opts.state_ref, opts.remote)
      if not safe then return nil, e end
      local history, herr = source.events(root, refs, prefix)
      if history == nil then return nil, herr end
      local present: {string: boolean} = {}
      for _, event in ipairs(history) do present[event.sha] = true end
      for sha in pairs(old.marks) do
        if not present[sha] then
          return nil, drift .. "; rewritten/deleted source history requires hand reconciliation: " .. sha
        end
      end
      old.sources, old.phase, old.snapshot_at, old.freeze = refs, "frozen", snapshot_at, opts.freeze
      local saved, saveerr = save(path, old)
      if not saved then return nil, saveerr end
    end
    if opts.freeze ~= nil then
      old.freeze = opts.freeze
      local saved, saveerr = save(path, old)
      if not saved then return nil, saveerr end
    end
    checkpoint = old
    if old.phase == "planned" then
      local present = source.git(root, {"cat-file", "-e", old.head .. "^{commit}"})
      if present == nil then return nil, "checkpoint replay head is missing" end
      local complete, cerr = source.integrity(root, {["replay"] = old.head})
      if not complete then return nil, cerr end
      local prior = source.git(root, {"show", old.head .. ":migration/sources"})
      if prior == archive_text then return old, "identical" end
      -- Upgrade an already completed pre-witness checkpoint by deterministically
      -- rebuilding only its final metadata commit from the preserved replay tip.
      old.phase = "frozen"
      local saved, saveerr = save(path, old)
      if not saved then return nil, saveerr end
    end
  end
  if checkpoint == nil then
    checkpoint = {version = "migrate6-v2", repository = repository, snapshot_at = snapshot_at, phase = "frozen", prefix = prefix,
      sources = refs, marks = {}, head = "", replayed_head = "", activation = "", count = 0, freeze = opts.freeze}
    local saved, err = save(path, checkpoint)
    if not saved then return nil, err end
  end
  local events, eerr = source.events(root, checkpoint.sources, prefix)
  if events == nil then return nil, eerr end
  local previous: replay.Result | nil = nil
  if checkpoint.head ~= "" then
    local complete, cerr = source.integrity(root, {["replay"] = checkpoint.head})
    if not complete then return nil, cerr end
    previous = {head = checkpoint.head, replayed_head = checkpoint.replayed_head,
      marks = checkpoint.marks, count = checkpoint.count}
  end
  local result, rerr = replay.replay(root, events, workdir, previous, archive_text)
  if result == nil then return nil, rerr end
  local same, drift = validate_sources(root, checkpoint)
  if not same then return nil, drift end
  checkpoint.head, checkpoint.replayed_head = result.head, result.replayed_head
  checkpoint.marks, checkpoint.count = result.marks, result.count
  checkpoint.activation, checkpoint.phase = result.head, "planned"
  local saved, err = save(path, checkpoint)
  if not saved then return nil, err end
  return checkpoint, "planned offline; activation requires verified freeze"
end

local record Migrate6
  type Checkpoint = Checkpoint
  type Options = Options
  run: function(root: string, opts?: Options): Checkpoint | nil, string
  read: function(string): Checkpoint | nil, string
  validate_sources: function(string, Checkpoint): boolean, string
  validate_catch_up: function(root: string, cp: Checkpoint, state_ref?: string, remote?: string): boolean, string
end
local M: Migrate6 = {run = run, read = read, validate_sources = validate_sources,
  validate_catch_up = validate_catch_up}
return M
