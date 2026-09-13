#!/usr/bin/env cosmic
local check = require("cosmic.check")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local fastimport = require("_work.fastimport")
local gitobj = require("_work.gitobj")
local migrate6 = require("_work.migrate6")
local source = require("_work.migrate6_source")
local replay = require("_work.migrate6_replay")
local boardtree = require("_work.boardtree")
local claimbatch = require("_work.claimbatch")

local function repo(name: string): string
  local root = fs.join(fixture.tmpdir, "migrate6-" .. name)
  assert(fs.remove_all(root))
  assert(fs.make_dirs(root))
  fixture.git(root, {"init", "-q"})
  return root
end

local function commit(root: string, ref: string, parent: string, meta: string,
    message: string, seconds?: integer): string
  local blob = check.must(gitobj.hash_object_write(root, meta))
  local tree = check.must(gitobj.mktree_write(root,
      {{mode = "100644", otype = "blob", sha = blob, name = "meta"}}))
  local date = tostring(seconds or 1700000000) .. " -0730"
  local text = "commit " .. ref .. "\nauthor Historical Author <author@test> " .. date ..
  "\ncommitter Historical Committer <committer@test> " .. date .. "\n" ..
  fastimport.data_block(message)
  if parent ~= "" then text = text .. "from " .. parent .. "\n" end
  text = text .. "M 040000 " .. tree .. " .\n"
  -- Root replacement with '.' is not a supported fast-import path; graft the
  -- one fixture blob instead, retaining exact message bytes.
  text = text:gsub("M 040000 [0-9a-f]+ %.\n", "") ..
  "M 100644 " .. blob .. " meta\ndone\n"
  check.must(source.git(root, {"fast-import", "--quiet", "--done"}, text))
  return (check.must(source.git(root, {"rev-parse", ref})):gsub("%s+$", ""))
end

local function test_migration_exact_history_logs_marks_and_offline_restart()
  local root = repo("history")
  local meta = "title: first\nbase: " .. ("1"):rep(40) .. "\n"
  local a = commit(root, "refs/heads/items/a", "", meta, "new a\n\nOp: new\n", 1700000010)
  local body = "log a\n\nresearch body\n\nOp: log" -- deliberately no final newline
  local b = commit(root, "refs/heads/items/a", a, meta, body, 1700000000)
  local c = commit(root, "refs/heads/ended/a", b, meta .. "result: " .. b .. "\n",
    "done a\n\nOp: done\n", 1700000030)
  fixture.git(root, {"update-ref", "-d", "refs/heads/items/a"})
  local d = commit(root, "refs/heads/items/z", "", "title: z\n", "new z\n", 1700000005)
  local cp = check.must(migrate6.run(root))
  assert(cp.count == 4)
  assert(cp.marks[a] ~= nil and cp.marks[b] ~= nil and cp.marks[c] ~= nil and cp.marks[d] ~= nil)
  local raw = check.must(source.git(root, {"cat-file", "commit", cp.marks[b]}))
  assert(raw:match("\n\n(.*)$") == body, "message byte preservation")
  assert(raw:find("author Historical Author <author@test> 1700000000 -0730", 1, true))
  local walk = check.must(source.git(root, {"rev-list", "--first-parent", "--reverse", cp.head}))
  assert(walk:find(cp.marks[d], 1, true) < walk:find(cp.marks[a], 1, true))
  assert(walk:find(cp.marks[a], 1, true) < walk:find(cp.marks[b], 1, true), "skewed clock preserves parent order")
  local entries = check.must(boardtree.snapshot_entries(root, cp.head))
  local logs = 0
  for _, entry in ipairs(entries) do
    if entry.path:match("^items/a/log/.*%.md$") then logs = logs + 1 end
  end
  assert(logs == 1, "later graft retains materialized log")
  local current_meta = check.must(source.git(root, {"show", cp.head .. ":items/a/meta"}))
  assert(current_meta:find("result: " .. cp.marks[b], 1, true))
  assert(current_meta:find("base: " .. ("1"):rep(40), 1, true), "product sha unchanged")
  local marks = check.must(boardtree.decode_marks(check.must(source.git(root, {"show", cp.head .. ":migration/marks"}))))
  assert(marks[b] == cp.marks[b])
  local again, status = migrate6.run(root)
  assert(again ~= nil and again.head == cp.head and status == "identical")
  assert(check.must(source.git(root, {"for-each-ref", "--format=%(refname)", "refs/heads/state"})) == "")
  local moved = commit(root, "refs/heads/ended/a", c, meta, "changed\n")
  local refused, drift = migrate6.run(root)
  assert(refused == nil and drift:find("moved refs/heads/ended/a", 1, true))
  fixture.git(root, {"update-ref", "refs/heads/state", moved})
  local safe, reason = migrate6.validate_catch_up(root, cp)
  assert(not safe and reason:find("native", 1, true))
end

local function test_claim_bridge_preserves_imported_root_on_expired_renewal()
  local root = repo("claims")
  local a = commit(root, "refs/heads/items/a", "", "title: a\n", "new a\n")
  local acquisition = check.must(claimbatch.create(root, {id = "acquire", caller = "alice",
        remote = "origin", action = "acquire", created_at = 1700000010,
        publish_by = 1700000100, why = "", rows = {{id = "a", item_tip = a,
            operation = "acquire", holder = "alice", product_base = a, root = "",
            acquired_at = 1700000010, renewed_at = 1700000010, expires_at = 1700000100}}}))
  fixture.git(root, {"update-ref", "refs/heads/claim-batches/acquire", acquisition.commit})
  local b = commit(root, "refs/heads/items/a", a, "title: a\nclaim_batch: " .. acquisition.commit .. "\n",
    "claim a\n\nOp: claim-bridge\n", 1700000011)
  local renewal = check.must(claimbatch.create(root, {id = "renew", caller = "alice",
        remote = "origin", action = "renew", created_at = 1700000020,
        publish_by = 1700000200, why = "", rows = {{id = "a", item_tip = b,
            operation = "renew", holder = "alice", product_base = a, root = acquisition.commit,
            acquired_at = 1700000010, renewed_at = 1700000020, expires_at = 1700000200}}}))
  fixture.git(root, {"update-ref", "refs/heads/claim-batches/renew", renewal.commit})
  commit(root, "refs/heads/items/a", b, "title: a\nclaim_batch: " .. renewal.commit .. "\n",
    "renew a\n\nOp: claim-bridge\n", 1700000021)
  local cp = check.must(migrate6.run(root))
  local claim = check.must(boardtree.decode_claim(check.must(source.git(root, {"show", cp.head .. ":claims/a"}))))
  assert(claim.id == acquisition.commit and claim.renewed_at == 1700000020)
  assert(claim.product_base == a, "product reference not remapped even if equal to board source")
  local diff = check.must(source.git(root, {"diff-tree", "--no-commit-id", "--name-only", "-r", cp.marks[b]}))
  assert(diff == "claims/a\n", "claim bridge remains an attributable claim-only event")
end

local function test_refset_integrity_and_mark_validation()
  local root = repo("integrity")
  local a = commit(root, "refs/heads/items/a", "", "title: a\n", "new a\n")
  local cp = check.must(migrate6.run(root))
  fixture.git(root, {"update-ref", "refs/heads/items/added", a})
  local ok, err = migrate6.validate_sources(root, cp)
  assert(not ok and err:find("added refs/heads/items/added", 1, true))
  fixture.git(root, {"update-ref", "-d", "refs/heads/items/a"})
  ok, err = migrate6.validate_sources(root, cp)
  assert(not ok and err:find("removed refs/heads/items/a", 1, true))
  fixture.git(root, {"config", "remote.origin.promisor", "true"})
  ok, err = source.integrity(root, cp.sources)
  assert(not ok and err:find("promisor", 1, true))
  local marks = replay.parse_marks(":" .. a .. " " .. a .. "\n", {})
  assert(marks == nil, "Git marks are ordinal ids, not old shas")
  assert(replay.remap_meta("base: " .. a .. "\nresult: " .. a .. "\n", {[a] = ("f"):rep(40)}) ==
    "base: " .. a .. "\nresult: " .. ("f"):rep(40) .. "\n")
end

local function test_catch_up_appends_without_rewriting_marks_or_losing_logs()
  local root = repo("catchup")
  local a = commit(root, "refs/heads/items/a", "", "title: a\n", "new a\n")
  local b = commit(root, "refs/heads/items/a", a, "title: a\n", "log a\n\nfirst\n")
  local cp = check.must(migrate6.run(root))
  fixture.git(root, {"update-ref", "refs/heads/state", cp.head})
  local c = commit(root, "refs/heads/items/a", b, "title: a\n", "log a\n\nsecond\n", 1700000010)
  local caught = check.must(migrate6.run(root, {catch_up = true}))
  assert(caught.marks[a] == cp.marks[a] and caught.marks[b] == cp.marks[b])
  assert(caught.marks[c] ~= nil and caught.head ~= cp.head)
  check.must(source.git(root, {"merge-base", "--is-ancestor", cp.head, caught.head}))
  local entries = check.must(boardtree.snapshot_entries(root, caught.head))
  local logs = 0
  for _, entry in ipairs(entries) do
    if entry.path:match("^items/a/log/") then logs = logs + 1 end
  end
  assert(logs == 2, "catchup keeps old materialized logs and adds the new event")
  local same, status = migrate6.run(root)
  assert(same ~= nil and same.head == caught.head and status == "identical")
end

local function test_checkpoint_restart_and_missing_source_closure()
  local wire = require("_work.singlehead_literal")
  local root = repo("restart")
  local a = commit(root, "refs/heads/items/a", "", "title: restart\n", "new a\n")
  local cp = check.must(migrate6.run(root))
  local expected = cp.head
  cp.phase, cp.head, cp.replayed_head, cp.activation, cp.marks, cp.count = "frozen", "", "", "", {}, 0
  assert(fs.write(fs.join(root, "o/migrate6/checkpoint.literal"), check.must(wire.encode(cp)), {atomic = true}))
  local resumed = check.must(migrate6.run(root))
  assert(resumed.head == expected, "restart rebuild is byte-identical")
  assert(fs.write(fs.join(root, ".git/shallow"), a .. "\n"))
  local ok, err = source.integrity(root, cp.sources)
  assert(not ok and err:find("shallow", 1, true))
  assert(fs.remove(fs.join(root, ".git/shallow")))
  local broken = repo("missing")
  local unique = "title: unique missing blob\n"
  local b = commit(broken, "refs/heads/items/b", "", unique, "new b\n")
  local blob = check.must(gitobj.hash_object(broken, unique))
  assert(fs.remove(fs.join(broken, ".git/objects", blob:sub(1, 2), blob:sub(3))))
  ok, err = source.integrity(broken, {["refs/heads/items/b"] = b})
  assert(not ok and err:find("missing source closure", 1, true))
end

local function test_synthetic_freeze_staged_seed_and_atomic_activation()
  local publisher = require("_work.migrate6_publish")
  local root = repo("publish")
  local a = commit(root, "refs/heads/items/a", "", "title: a\n", "new a\n")
  local b = commit(root, "refs/heads/items/a", a, "title: a\n", "log a\n\nbody\n")
  local remote = fs.join(fixture.tmpdir, "migrate6-publish-remote.git")
  assert(fs.remove_all(remote))
  fixture.git(root, {"clone", "--bare", "--quiet", root, remote})
  fixture.git(root, {"remote", "add", "origin", remote})
  local hook = [[#!/bin/sh
while read old new ref; do
  case "$ref" in
    refs/heads/items/*|refs/heads/ended/*|refs/heads/claim-batches/*|refs/heads/board/seq)
      echo 'legacy freeze' >&2
      exit 1;;
  esac
done
exit 0
]]
  local witness = fs.join(remote, "hooks/pre-receive")
  assert(fs.write(witness, hook, {mode = 493}))
  local frozen_at = os.time()
  local cp = check.must(migrate6.run(root))
  local proof: publisher.FreezeProof = {destination = remote, witness = witness, frozen_at = frozen_at}
  local function verify(p: publisher.FreezeProof): boolean, string
    local bytes = fs.read(p.witness)
    return p.destination == remote and bytes == hook, "fixture ruleset is not effective"
  end
  local old_client, olderr = source.git(root, {"push", "origin", b .. ":refs/heads/items/new"})
  assert(old_client == nil and olderr:find("legacy freeze", 1, true), "freeze blocks legacy creation")
  local plan = check.must(publisher.prepare_activation(root, cp, "origin", 1, proof, verify))
  assert(#plan.stages == 2 and plan.activation[3] == "--atomic")
  local first: {string} = {}
  for i = 2, #plan.stages[1] do first[#first + 1] = plan.stages[1][i] end
  check.must(source.git(root, first))
  assert(check.must(source.git(remote, {"for-each-ref", "--format=%(refname)", "refs/heads/board/format"})) == "",
    "partial seed leaves marker absent")
  local remaining = check.must(publisher.prepare_activation(root, cp, "origin", 1, proof, verify))
  assert(#remaining.stages == 1, "rerun skips already seeded ancestors")
  fixture.git(remote, {"update-ref", "refs/heads/items/added", a})
  local refused, drift = publisher.prepare_activation(root, cp, "origin", 1, proof, verify)
  assert(refused == nil and drift:find("added refs/heads/items/added", 1, true))
  fixture.git(remote, {"update-ref", "-d", "refs/heads/items/added"})
  fixture.git(remote, {"update-ref", "-d", "refs/heads/items/a"})
  refused, drift = publisher.prepare_activation(root, cp, "origin", 1, proof, verify)
  assert(refused == nil and drift:find("removed refs/heads/items/a", 1, true))
  fixture.git(remote, {"update-ref", "refs/heads/items/a", a})
  refused, drift = publisher.prepare_activation(root, cp, "origin", 1, proof, verify)
  assert(refused == nil and drift:find("moved refs/heads/items/a", 1, true))
  fixture.git(remote, {"update-ref", "refs/heads/items/a", b})
  local landed, err = publisher.publish(root, cp, "origin", 1, proof, verify)
  assert(landed, err)
  assert(check.must(source.git(remote, {"show", "refs/heads/board/format:format"})) == "6\n")
  assert(check.must(source.git(remote, {"rev-parse", "refs/heads/state"})) == cp.head .. "\n")
  local wrong: publisher.FreezeProof = {destination = "wrong", witness = witness, frozen_at = frozen_at}
  refused, drift = publisher.prepare_activation(root, cp, "origin", 1, wrong, verify)
  assert(refused == nil and drift:find("destination", 1, true))
  assert(fs.write(witness, "#!/bin/sh\nexit 0\n", {mode = 493}))
  refused, drift = publisher.prepare_activation(root, cp, "origin", 1, proof, verify)
  assert(refused == nil and drift:find("freeze verification refused", 1, true))
end
