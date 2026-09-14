--- Explicit shell migration commands. Offline plans never imply a live freeze.
local fs = require("cosmic.fs")
local gate = require("_work.gitgate")
local refs = require("_work.refs")
local migrate = require("_work.migrate6")
local freeze = require("_work.migrate6_freeze")
local probes = require("_work.migrate6_probes")
local publish = require("_work.migrate6_publish")
local diagnostics = require("_work.migrate6_diagnostics")
local literal = require("_work.singlehead_literal")

--- `gitboard migrate6`: `prepare-freeze` seeds sacrificial refs before an
--- owner enables the ruleset; `plan
--- --freeze-ruleset ID` binds an observed and probed legacy-write freeze to the
--- source snapshot, `verify-source` and `verify-remote` re-compare the ref set,
--- `activation-plan` renders the staged pushes, and `publish --execute` is the
--- only action that writes to a destination. The CLI accepts no boolean claiming
--- a freeze was verified: the verifier is called here, with the checkpoint's own
--- bound proof.
--- @param root string The source board checkout
--- @param args {string} The action, defaulting to `plan`
--- @param values {string: string} The flag values
--- @param switches {string: boolean} The flag switches
--- @return integer The verdict line's exit status
local function run(root: string, args: {string}, values: {string: string}, switches: {string: boolean}): integer
  local action = args[1] or "plan"
  local path = values.checkpoint or fs.join(root, "o/migrate6/checkpoint.literal")
  local probes_path = values["freeze-probes"] or (path .. ".freeze-probes.literal")
  local remote = values.remote or refs.board_remote(root)
  local cp: migrate.Checkpoint | nil = nil
  local err = ""
  if action == "prepare-freeze" then
    local destination, derr = freeze.destination(root, remote)
    if destination == nil then return gate.verdict_line("migrate6", false, derr) end
    local manifest, merr = probes.prepare(root, destination, probes_path, nil, nil)
    if manifest == nil then return gate.verdict_line("migrate6", false, merr) end
    return gate.verdict_line("migrate6", true,
      "sacrificial refs seeded; enable the freeze, then run plan --freeze-ruleset ID")
  elseif action == "plan" then
    local prefix = values.prefix or (refs.board_mode(root) == "local" and "refs/heads/"
      or "refs/remotes/" .. remote .. "/")
    local proof: freeze.Proof = nil
    if values["freeze-ruleset"] ~= nil then
      local id = tonumber(values["freeze-ruleset"])
      if id == nil or id < 1 or id % 1 ~= 0 then return gate.verdict_line("migrate6", false, "freeze-ruleset must be a positive integer") end
      local previous_prefix: string = nil
      local previous_probes: probes.Manifest = nil
      if fs.is_present(path) then
        local previous, perr = migrate.read(path)
        if previous == nil then return gate.verdict_line("migrate6", false, perr) end
        if previous.freeze == nil then return gate.verdict_line("migrate6", false, "offline checkpoint cannot acquire a retroactive freeze; choose a new checkpoint path") end
        previous_prefix = previous.prefix
        previous_probes = previous.freeze.probes
      end
      local manifest, merr = probes.read(probes_path)
      if manifest == nil then return gate.verdict_line("migrate6", false,
          "prepare-freeze must seed sacrificial refs before enabling the ruleset: " .. merr) end
      if previous_probes ~= nil then
        local prior, prior_err = probes.digest(previous_probes)
        if prior == nil then return gate.verdict_line("migrate6", false, prior_err) end
        local current, current_err = probes.digest(manifest)
        if current == nil then return gate.verdict_line("migrate6", false, current_err) end
        if prior ~= current then return gate.verdict_line("migrate6", false,
            "freeze probe manifest differs from checkpoint; reuse the original manifest") end
      end
      local snapshot, serr = freeze.snapshot(root, remote, id as integer, -- cast: tonumber result is integral and positive
        manifest, nil, nil, previous_prefix)
      if snapshot == nil then return gate.verdict_line("migrate6", false, serr) end
      prefix, proof = snapshot.proof.prefix, snapshot.proof
    end
    cp, err = migrate.run(root, {checkpoint = path, prefix = prefix, freeze = proof,
        catch_up = switches["catch-up"] or false, state_ref = prefix .. "state",
        remote = (proof ~= nil or refs.board_mode(root) ~= "local") and remote or nil})
  else cp, err = migrate.read(path) end
  if cp == nil then return gate.verdict_line("migrate6", false, err) end
  if action == "verify-source" then
    local valid, verr = migrate.validate_sources(root, cp)
    return gate.verdict_line("migrate6", valid, valid and "source ref set matches checkpoint" or verr)
  elseif action == "verify-remote" then
    local actual, aerr = publish.verify_sources(root, cp, remote)
    return gate.verdict_line("migrate6", actual ~= nil, actual ~= nil and "complete destination source ref set matches" or aerr)
  elseif action == "activation-plan" or action == "publish" then
    local limit = tonumber(values.limit or "100")
    if limit == nil or limit < 1 or limit % 1 ~= 0 then return gate.verdict_line("migrate6", false, "limit must be a positive integer") end
    if action == "publish" and switches.execute then
      if cp.freeze == nil then return gate.verdict_line("migrate6", false,
          "publication requires plan --freeze-ruleset ID with a fresh frozen source snapshot") end
      local checkpoint = cp
      local proof: publish.FreezeProof = {destination = cp.freeze.before.destination,
        witness = cp.freeze.source_digest, frozen_at = cp.freeze.before.updated_at}
      local function verify(_ignored: publish.FreezeProof): boolean, string
        return freeze.verify(root, remote, checkpoint.freeze, checkpoint.sources)
      end
      local ok, perr = publish.publish(root, cp, remote, limit as integer, proof, verify) -- cast: integral limit checked
      return gate.verdict_line("migrate6", ok, ok and "state and format 6 activated atomically" or perr)
    end
    local planned, perr = publish.plan(root, cp, remote, limit as integer) -- cast: integral limit checked
    if planned == nil then return gate.verdict_line("migrate6", false, perr) end
    local encoded, eerr = literal.encode(planned)
    if encoded == nil then return gate.verdict_line("migrate6", false, eerr) end
    print(encoded)
    return gate.verdict_line("migrate6", true, "review only; publish --execute re-verifies gh freeze and complete destination source set")
  elseif action ~= "plan" and action ~= "show" then
    return gate.verdict_line("migrate6", false, "action must be prepare-freeze, plan, show, verify-source, verify-remote, activation-plan, or publish")
  end
  if cp == nil then return gate.verdict_line("migrate6", false, "checkpoint unavailable") end
  local report: diagnostics.Report = {fields = {}, results = {}, count = 0}
  if cp.head ~= "" then
    local found, rerr = diagnostics.inspect(root, cp.head, cp.marks)
    if found == nil then return gate.verdict_line("migrate6", false, rerr) end
    report = found
  end
  -- Every unmapped evidence field is NAMED, not just counted: a `verdict_head`
  -- or `landed_head` the marks cannot resolve is a dangling reference the
  -- operator has to see before activating, exactly as an unmapped `result` is.
  local summary, serr = literal.encode({checkpoint = path, head = cp.head, count = cp.count,
      phase = cp.phase, freeze = cp.freeze ~= nil, unmapped_evidence = report.count,
      unmapped_fields = report.fields, unmapped_results = report.results})
  if summary == nil then return gate.verdict_line("migrate6", false, serr) end
  print(summary)
  return gate.verdict_line("migrate6", true, action == "plan" and err or "checkpoint inspected")
end
local record Cli
  run: function(string, {string}, {string: string}, {string: boolean}): integer
end
local M: Cli = {run = run}
return M
