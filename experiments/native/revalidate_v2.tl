#!/usr/bin/env cosmic
--- Local compatibility proof; historical expired plans are never executed.
local check = require("cosmic.check")
local fs = require("cosmic.fs")
local literal = require("_work.singlehead_literal")
local saved = require("_work.stateplan_file")
local git = require("_work.singlehead_git")
local tx = require("_work.statetransaction")
local plans = require("_work.stateplan")
local receipts = require("_work.stateplan_receipts")
local root, old_directory, out = assert(arg[1]), assert(arg[2]), assert(arg[3])
local head = check.must(git.oid(root, "refs/heads/state"))
local results: {{string: any}} = {}
for _, name in ipairs({"log", "draft", "claim", "drop", "sibling", "bounded"}) do
  local old_path = fs.join(old_directory, name, "plan.literal")
  local wrapper = check.must(literal.decode_object(check.must(fs.read(old_path))))
  local rawplan = wrapper.plan as {string: any} -- cast: schema checked by frozen validation and fresh planner
  local frozen = check.must(tx.freeze(rawplan.frozen as tx.Frozen)) -- cast: untrusted stored record validated by freeze
  assert(frozen.branch == "validation/gitboard-format6-20260913" and frozen.repository == "cosmic-lua/work")
  local expected = rawplan.expected_head
  local deadline = rawplan.publish_by
  assert(expected is string and deadline is integer)
  local historical_time = deadline > 0 and deadline - 1 or os.time()
  local fresh = check.must(plans.build(root, frozen, expected, nil, historical_time))
  assert(literal.encode(fresh.frozen) == literal.encode(rawplan.frozen), "regeneration changed original frozen bytes")
  assert(plans.validate_local(root, fresh))
  assert(plans.save(fs.join(out, name .. ".literal"), fresh))
  local observed = check.must(receipts.inspect(root, head, fresh.frozen))
  local published = name == "log" or name == "draft" or name == "claim" or name == "drop"
  assert(observed.status == (published and "confirmed" or "pending"))
  local old_loaded, old_error = plans.load(old_path)
  assert(old_loaded == nil and old_error:find("regenerate", 1, true), "v1 attempt must be rejected without rewriting")
  results[#results + 1] = {scenario = name, status = observed.status, published_sha = observed.candidate,
    frozen_bytes_unchanged = true, plan_format = fresh.format, expected_head = fresh.expected_head,
    final_guard = fresh.calls[#fresh.calls].guard, old_plan_rejected = old_error}
end
local report = {format = "gitboard-native-v2-local-revalidation-v1", head = head, results = results,
  remote_mutations = 0, expired_claim_plan_execution = false}
assert(saved.write_once(fs.join(out, "report.literal"), check.must(literal.encode(report))))
print(check.must(literal.encode(report)))
