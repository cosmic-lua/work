--- Explicit GitHub freeze verification. Only this provider invokes `gh`; it
--- never discovers tokens, changes a ruleset, or accepts a caller's boolean.
local child = require("cosmic.child")
local hash = require("cosmic.hash")
local json = require("cosmic.json")
local ksuid = require("cosmic.ksuid")
local time = require("cosmic.time")
local wire = require("_work.singlehead_literal")
local source = require("_work.migrate6_source")
local probes = require("_work.migrate6_probes")

local record Observation
  repository: string
  destination: string
  ruleset_id: integer
  updated_at: integer
  observed_at: integer
  digest: string
end
local record Proof
  before: Observation
  after: Observation
  prefix: string
  source_digest: string
  probes: probes.Manifest
  --- Every fenced-namespace write this freeze actually REFUSED, attempt name
  --- to the destination's own refusal text. A read of the ruleset says the
  --- fence is configured; these say it bites.
  refusals: {string: string}
end
local record Snapshot
  proof: Proof
  sources: {string: string}
end
local type Provider = function(string, integer): string | nil, string
local type Fetcher = function(string, string, string): boolean, string
local type Pusher = probes.Pusher
local type Reader = probes.Reader
local REQUIRED < const >: {string: boolean} = {
  ["refs/heads/items/**"] = true, ["refs/heads/ended/**"] = true,
  ["refs/heads/claim-batches/**"] = true, ["refs/heads/board/seq"] = true,
}

--- @param root string Source repository
--- @param remote string Configured push remote
--- @return string | nil Exact Git push destination
--- @return string Failure diagnostic
local function destination(root: string, remote: string): string | nil, string
  if remote == "" or remote:sub(1, 1) == "-" or remote:find("[%c]") then return nil, "invalid remote" end
  local url, err = source.git(root, {"remote", "get-url", "--push", remote})
  if url == nil then return nil, err end
  return (url:gsub("%s+$", "")), ""
end

--- @param url string Exact push URL
--- @return string | nil GitHub owner/repository, otherwise refusal
--- @return string Failure diagnostic
local function repository(url: string): string | nil, string
  local repo = url:match("^https://github%.com/([%w_.%-]+/[%w_.%-]+)$")
  or url:match("^git@github%.com:([%w_.%-]+/[%w_.%-]+)$")
  or url:match("^ssh://git@github%.com/([%w_.%-]+/[%w_.%-]+)$")
  if repo == nil then return nil, "verified migration requires a github.com push destination" end
  return (repo:gsub("%.git$", "")), ""
end

--- @param repo string GitHub owner/repository
--- @param id integer Ruleset id selected explicitly by the owner
--- @return string | nil HTTP status, headers and public ruleset JSON
--- @return string Actionable gh/auth failure, never credentials
local function gh(repo: string, id: integer): string | nil, string
  local r, err = child.run({"gh", "api", "--hostname", "github.com", "--method", "GET", "--include",
      "-H", "Accept: application/vnd.github+json", "-H", "X-GitHub-Api-Version: 2026-03-10",
      "repos/" .. repo .. "/rulesets/" .. tostring(id) .. "?includes_parents=false"})
  if r == nil then return nil, "freeze verification requires authenticated GitHub CLI (gh): " .. err end
  if not r.ok then return nil, "gh could not read the ruleset; authenticate with ruleset write access: " .. r.stderr end
  return r.stdout, ""
end

--- Whether a decoded JSON field is an empty list — how the ruleset says "no
--- bypass actors" and "no exclusions", both of which the freeze requires.
--- @param value any A decoded JSON field
--- @return boolean True for an empty array
local function empty(value: any): boolean
  return value is {any} and next(value) == nil
end

--- @param raw string Included HTTP response from the concrete provider
--- @param url string Exact push destination
--- @param repo string Expected repository
--- @param id integer Expected ruleset id
--- @return Observation | nil Validated active freeze; unknown shapes refuse
--- @return string Missing coverage/access/enforcement diagnostic
local function inspect(raw: string, url: string, repo: string, id: integer): Observation | nil, string
  local normalized = raw:gsub("\r\n", "\n")
  local headers, body = normalized:match("^(.-)\n\n(.*)$")
  if headers == nil or not headers:match("^HTTP/%S+ 200") then return nil, "ruleset query did not return HTTP 200" end
  local date: string = nil
  for line in headers:gmatch("[^\n]+") do
    local key, value = line:match("^([^:]+):%s*(.*)$")
    if key ~= nil and key:lower() == "date" then date = value end
  end
  local observed = date and time.parse_http(date) or nil
  if observed == nil then return nil, "ruleset response lacks a valid server Date" end
  local value, jerr = json.decode(body)
  if not (value is {string: any}) then return nil, jerr or "ruleset response must be an object" end
  local raw_id, updated = value.id, value.updated_at
  if not (raw_id is integer) or raw_id ~= id or value.target ~= "branch"
  or value.enforcement ~= "active" or value.source_type ~= "Repository"
  or value.source ~= repo then return nil, "ruleset must actively freeze this repository's branches" end
  if not empty(value.bypass_actors) then
    return nil, "ruleset must expose an empty bypass_actors list (ruleset write access required)"
  end
  if not (updated is string) then return nil, "ruleset lacks updated_at" end
  local updated_at = time.parse_iso8601(updated)
  if updated_at == nil or updated_at > observed then return nil, "ruleset update is later than its observation" end
  local conditions = value.conditions
  if not (conditions is {string: any}) then return nil, "ruleset lacks ref conditions" end
  local ref_name = conditions.ref_name
  if not (ref_name is {string: any}) then return nil, "ruleset lacks ref-name coverage" end
  local included = ref_name.include
  if not (included is {any}) or #included ~= 4 or not empty(ref_name.exclude) then
    return nil, "freeze requires exactly the four legacy ref patterns and no exclusions"
  end
  local found: {string: boolean} = {}
  for _, pattern in ipairs(included) do
    if not (pattern is string) or not REQUIRED[pattern] or found[pattern] then return nil, "unsupported freeze ref pattern" end
    found[pattern] = true
  end
  local rules = value.rules
  if not (rules is {any}) or #rules ~= 3 then return nil, "freeze requires creation, update, and deletion rules" end
  local kinds: {string: boolean} = {}
  for _, rule in ipairs(rules) do
    if not (rule is {string: any}) then return nil, "invalid freeze rule" end
    local kind = rule.type
    if not (kind is string) or (kind ~= "creation" and kind ~= "update" and kind ~= "deletion")
    or kinds[kind] then return nil, "unsupported or duplicate freeze rule" end
    kinds[kind] = true
    if kind == "update" then
      local parameters = rule.parameters
      if not (parameters is {string: any}) or parameters.update_allows_fetch_and_merge ~= false then
        return nil, "freeze update rule must forbid fetch-and-merge bypass"
      end
    end
  end
  local canonical, cerr = wire.encode({repository = repo, id = id, updated_at = updated,
      include = found, rules = kinds, bypass = "none", exclusions = "none", fetch_and_merge = false})
  if canonical == nil then return nil, cerr end
  return {repository = repo, destination = url, ruleset_id = id, observed_at = observed,
    updated_at = updated_at, digest = hash.sha256_hex(canonical)}, ""
end

--- Prove the freeze BITES, not merely that it is configured: under every
--- globbed legacy namespace, attempt to create an absent manifest ref, force an
--- existing manifest ref to a distinct commit, and delete another existing
--- manifest ref. Only GitHub's ref-specific GH013 ruleset rejection counts:
--- authentication, transport and missing-ref failures prove no freeze.
--- @param root string Source repository, for its git binary and objects
--- @param url string The exact push destination the freeze is bound to
--- @param manifest probes.Manifest Sacrificial refs seeded before the freeze
--- @param pusher Pusher | nil Test seam; production always pushes
--- @param reader Reader | nil Exact remote-ref test seam
--- @return {string: string} | nil Attempt name -> the refusal it earned
--- @return string Failure diagnostic naming the attempt that was permitted
local function probe(root: string, url: string, manifest: probes.Manifest,
    pusher?: Pusher, reader?: Reader): {string: string} | nil, string
  if manifest.destination ~= url then return nil, "freeze probe destination differs" end
  local ready, rerr = probes.verify(root, manifest, reader)
  if not ready then return nil, rerr end
  local push = pusher or probes.push
  local out: {string: string} = {}
  for _, namespace in ipairs(probes.namespaces) do
    local attempts: {{string}} = {
      {"create", manifest.new_sha .. ":" .. manifest.refs[probes.key("create", namespace)]},
      {"update", "--force", manifest.new_sha .. ":" .. manifest.refs[probes.key("update", namespace)]},
      {"delete", ":" .. manifest.refs[probes.key("delete", namespace)]},
    }
    for _, attempt in ipairs(attempts) do
      local args: {string} = {}
      for index = 2, #attempt do args[#args + 1] = attempt[index] end
      local accepted, detail = push(root, url, args)
      local ref = attempt[#attempt]:match(":(refs/heads/.*)$") or ""
      if accepted then
        local restore: {string}
        if attempt[1] == "create" then restore = {"--force", ":" .. ref}
        else restore = {"--force", manifest.old_sha .. ":" .. ref} end
        local restored, restore_err = push(root, url, restore)
        local suffix = restored and "" or "; sacrificial ref restore failed: " .. restore_err
        return nil, ("freeze does not refuse %s of %s%s"):format(attempt[1], ref, suffix)
      end
      if not detail:find("GH013: Repository rule violations found for " .. ref, 1, true)
      or not detail:find("push declined due to repository rule violations", 1, true) then
        return nil, ("%s of %s did not prove a GitHub ruleset refusal: %s"):format(attempt[1], ref, detail)
      end
      out[attempt[1] .. " " .. ref] = detail
    end
  end
  local unchanged, uerr = probes.verify(root, manifest, reader)
  if not unchanged then return nil, "sacrificial refs changed during freeze probe: " .. uerr end
  return out, ""
end

--- @param root string Source repository
--- @param remote string Explicit configured remote
--- @param id integer Explicit ruleset id
--- @param provider Provider | nil Test response seam; production always gh
--- @return Observation | nil Validated live provider observation
--- @return string Failure diagnostic
local function observe(root: string, remote: string, id: integer, provider?: Provider): Observation | nil, string
  if id < 1 then return nil, "freeze ruleset id must be positive" end
  local url, uerr = destination(root, remote); if url == nil then return nil, uerr end
  local repo, rerr = repository(url); if repo == nil then return nil, rerr end
  local raw, err = (provider or gh)(repo, id); if raw == nil then return nil, err end
  return inspect(raw, url, repo, id)
end

--- Fetch every branch of the destination into this run's own private namespace,
--- so the snapshot the checkpoint freezes cannot be disturbed by, or disturb,
--- any board reader's tracking refs.
--- @param root string The repository to fetch into
--- @param url string The exact destination
--- @param prefix string The private namespace to land them under
--- @return boolean True on success
--- @return string Error message
local function fetch_source(root: string, url: string, prefix: string): boolean, string
  local fetched, err = source.git(root, {"fetch", "--no-tags", "--prune", url, "+refs/heads/*:" .. prefix .. "*"})
  return fetched ~= nil, err
end

--- @param before Observation Observed before starting a fresh source fetch
--- @param after Observation Re-observed after that fetch finished
--- @return boolean Whether the unchanged ruleset brackets the fetch
--- @return string Ordering or changed-freeze diagnostic
local function brackets(before: Observation, after: Observation): boolean, string
  if before.destination ~= after.destination or before.repository ~= after.repository
  or before.ruleset_id ~= after.ruleset_id or before.digest ~= after.digest
  or before.updated_at ~= after.updated_at then return false, "freeze changed while fetching source snapshot" end
  if before.observed_at < before.updated_at or after.observed_at < before.observed_at then
    return false, "freeze observations do not bracket the source fetch in server-time order"
  end
  return true, ""
end

--- Whether a decoded checkpoint field has every field an observation needs, of
--- the right type — checked before a proof from disk is trusted at all.
--- @param raw any A field from the decoded checkpoint
--- @return boolean True when the shape is an observation
local function observation_shape(raw: any): boolean
  if not (raw is {string: any}) then return false end
  for _, key in ipairs({"repository", "destination", "digest"}) do
    local value = raw[key]
    if not (value is string) or value == "" then return false end
  end
  for _, key in ipairs({"ruleset_id", "updated_at", "observed_at"}) do
    local value = raw[key]
    if not (value is integer) or value < 1 then return false end
  end
  return true
end

--- @param raw any Literal checkpoint field, never executable witness code
--- @return Proof | nil Structurally valid bound proof
--- @return string Failure diagnostic
local function decode(raw: any): Proof | nil, string
  if not (raw is {string: any}) then return nil, "freeze proof must be a literal object" end
  local prefix, digest = raw.prefix, raw.source_digest
  if not observation_shape(raw.before) or not observation_shape(raw.after)
  or not (prefix is string) or not prefix:match("^refs/gitboard/migrate6/source%-%w+/$")
  or not (digest is string) or #digest ~= 64 or not digest:match("^[0-9a-f]+$") then
    return nil, "invalid freeze proof fields"
  end
  local refusals = raw.refusals
  if not (refusals is {string: any}) then return nil, "freeze proof lacks recorded refusals" end
  local manifest, merr = probes.decode(raw.probes)
  if manifest == nil then return nil, merr end
  local proved = 0
  for attempt, detail in pairs(refusals) do
    if not (detail is string) or detail == "" then return nil, "freeze refusal must record its text" end
    local kind, ref = attempt:match("^(%a+) (refs/heads/.+)$")
    local known = false
    for _, namespace in ipairs(probes.namespaces) do
      if kind ~= nil and ref == manifest.refs[probes.key(kind, namespace)] then known = true end
    end
    if not known then return nil, "unknown freeze refusal attempt" end
    proved = proved + 1
  end
  if proved ~= 3 * #probes.namespaces then return nil, "freeze proof must refuse create, update and delete in every namespace" end
  local proof = raw as Proof -- cast: field shapes verified above
  local valid, err = brackets(proof.before, proof.after)
  if not valid then return nil, err end
  return proof, ""
end

--- @param root string Local repository
--- @param remote string Explicit configured remote
--- @param id integer Owner-specified ruleset id
--- @param provider Provider | nil Validated HTTP-response test seam
--- @param fetcher Fetcher | nil Isolated fetch test seam
--- @return Snapshot | nil Fresh private source namespace and bound freeze proof
--- @return string Failure diagnostic
local function snapshot(root: string, remote: string, id: integer, manifest: probes.Manifest,
    provider?: Provider, fetcher?: Fetcher, existing_prefix?: string,
    pusher?: Pusher, reader?: Reader): Snapshot | nil, string
  if existing_prefix ~= nil and not existing_prefix:match("^refs/gitboard/migrate6/source%-%w+/$") then
    return nil, "verified catch-up requires an owned private source prefix"
  end
  local before, err = observe(root, remote, id, provider); if before == nil then return nil, err end
  local refusals, perr = probe(root, before.destination, manifest, pusher, reader)
  if refusals == nil then return nil, perr end
  local prefix = existing_prefix or ("refs/gitboard/migrate6/source-" .. ksuid.new() .. "/")
  local fetched, ferr = (fetcher or fetch_source)(root, before.destination, prefix)
  if not fetched then return nil, ferr end
  local after, aerr = observe(root, remote, id, provider); if after == nil then return nil, aerr end
  local valid, verr = brackets(before, after); if not valid then return nil, verr end
  local all_refs, rerr = source.snapshot(root, prefix); if all_refs == nil then return nil, rerr end
  local refs, filter_err = probes.filter(all_refs, prefix, manifest); if refs == nil then return nil, filter_err end
  local encoded, eerr = wire.encode(refs); if encoded == nil then return nil, eerr end
  return {sources = refs, proof = {before = before, after = after, prefix = prefix,
      refusals = refusals, probes = manifest, source_digest = hash.sha256_hex(encoded)}}, ""
end

--- @param root string Repository holding the immutable checkpoint
--- @param remote string Explicit configured remote
--- @param proof Proof Observation pair generated around the source fetch
--- @param refs {string:string} Frozen source map
--- @param provider Provider | nil Validated response test seam
--- @return boolean Whether this exact freeze still holds for the snapshot
--- @return string Failure diagnostic
local function verify(root: string, remote: string, proof: Proof, refs: {string: string},
    provider?: Provider, pusher?: Pusher, reader?: Reader): boolean, string
  local bracketed, berr = brackets(proof.before, proof.after); if not bracketed then return false, berr end
  local encoded, err = wire.encode(refs); if encoded == nil then return false, err end
  if hash.sha256_hex(encoded) ~= proof.source_digest then return false, "freeze witness source snapshot differs" end
  for ref in pairs(refs) do
    if ref:sub(1, #proof.prefix) ~= proof.prefix then return false, "freeze witness source prefix differs" end
  end
  local current, cerr = observe(root, remote, proof.before.ruleset_id, provider)
  if current == nil then return false, cerr end
  local bracketed_now, nerr = brackets(proof.after, current)
  if not bracketed_now then return false, nerr end
  local refusals, perr = probe(root, current.destination, proof.probes, pusher, reader)
  if refusals == nil then return false, perr end
  return true, ""
end

local record Freeze
  type Observation = Observation
  type Proof = Proof
  type Snapshot = Snapshot
  type Provider = Provider
  type Fetcher = Fetcher
  type Pusher = Pusher
  type Reader = Reader
  destination: function(string, string): string | nil, string
  repository: function(string): string | nil, string
  inspect: function(string, string, string, integer): Observation | nil, string
  brackets: function(Observation, Observation): boolean, string
  decode: function(any): Proof | nil, string
  probe: function(root: string, url: string, manifest: probes.Manifest, pusher?: Pusher, reader?: Reader): {string: string} | nil, string
  snapshot: function(root: string, remote: string, id: integer, manifest: probes.Manifest, provider?: Provider, fetcher?: Fetcher, existing_prefix?: string, pusher?: Pusher, reader?: Reader): Snapshot | nil, string
  verify: function(root: string, remote: string, proof: Proof, refs: {string: string}, provider?: Provider, pusher?: Pusher, reader?: Reader): boolean, string
end
local M: Freeze = {destination = destination, repository = repository, inspect = inspect, brackets = brackets, decode = decode,
  probe = probe, snapshot = snapshot, verify = verify}
return M
