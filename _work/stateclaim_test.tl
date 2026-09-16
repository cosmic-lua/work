#!/usr/bin/env cosmic
local check = require("cosmic.check")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local refs = require("_work.refs")
local boardtree = require("_work.boardtree")
local native = require("_work.stateclaim")
local NOW < const > = 1900000000
local ALICE < const > = "0123456789abcdef0123456789abcdef"
local BOB < const > = "abcdef0123456789abcdef0123456789"
local BASE < const > = "0123456789012345678901234567890123456789"
local function setup(name: string): string, string
  local root = fs.join(fixture.tmpdir, "native-claim-" .. name)
  assert(fs.remove_all(root)); assert(fs.make_dirs(root .. "/items/a"))
  assert(fs.make_dirs(root .. "/items/b")); assert(fs.make_dirs(root .. "/claims"))
  fixture.git(root, {"init", "-q"})
  assert(fs.write(root .. "/format", "6\n"))
  assert(fs.write(root .. "/items/a/meta", "kind: task\ntitle: A\n"))
  assert(fs.write(root .. "/items/b/meta", "kind: task\ntitle: B\n"))
  fixture.git(root, {"add", "."}); fixture.git(root, {"commit", "-qm", "native base"})
  return root, check.must(refs.read_ref(root, "HEAD"))
end
local function apply(root: string, result: native.Result): string
  assert(next(result.refused) == nil)
  for _, c in ipairs(result.changes) do
    if c.delete then assert(fs.remove(root .. "/" .. c.path))
    else assert(fs.write(root .. "/" .. c.path, c.content)) end
  end
  fixture.git(root, {"add", "."}); fixture.git(root, {"commit", "--allow-empty", "-qm", "claim"})
  return check.must(refs.read_ref(root, "HEAD"))
end
local function prepare(root: string, head: string, action: native.Action, who: string,
    now: integer, force?: boolean, why?: string): native.Result
  return native.prepare(root, head, {{id = "a", product_base = BASE}}, action, who, now, force or false, why or "")
end
local function test_identity_overlap_renew_expiry_and_drop()
  local root, head = setup("lifecycle")
  local acquired = prepare(root, head, "take", ALICE, NOW)
  assert(#acquired.dependencies == 2)
  assert(acquired.dependencies[1].path == "items/a")
  assert(acquired.dependencies[2].id == boardtree.ZERO_SHA)
  local id = acquired.members[1].claim_root
  assert(#id == 40 and id:match("^[0-9a-f]+$"))
  head = apply(root, acquired)
  local held = prepare(root, head, "take", ALICE, NOW + 1)
  assert(held.refused.a ~= nil and #held.members == 0 and #held.changes == 0)
  local renewed = prepare(root, head, "renew", ALICE, NOW + 100)
  assert(renewed.members[1].claim_root == id and renewed.publish_by == NOW + 7200)
  head = apply(root, renewed)
  assert(next(prepare(root, head, "renew", ALICE, NOW + 7400).refused) ~= nil)
  local again = prepare(root, head, "take", ALICE, NOW + 7400)
  assert(again.members[1].claim_root ~= id)
  local drop = prepare(root, head, "drop", ALICE, NOW + 7400)
  assert(drop.changes[1].delete and drop.publish_by == 0)
  apply(root, drop)
end
local function test_atomic_refusal_force_and_minimum_deadline()
  local root, head = setup("atomic")
  head = apply(root, prepare(root, head, "take", ALICE, NOW))
  local denied = native.prepare(root, head, {{id = "b", product_base = BASE}, {id = "a", product_base = BASE}},
    "take", BOB, NOW + 1, false, "")
  assert(denied.refused.a ~= nil and #denied.changes == 0 and #denied.members == 0)
  assert(next(prepare(root, head, "take", BOB, NOW + 1, true, "").refused) ~= nil)
  local forced = prepare(root, head, "take", BOB, NOW + 1, true, "session lost")
  assert(forced.refused.a ~= nil and #forced.members == 0 and #forced.changes == 0)
  local mixed = native.prepare(root, head, {{id = "b", product_base = BASE}, {id = "a", product_base = BASE}},
    "take", ALICE, NOW + 100, false, "")
  assert(mixed.refused.a ~= nil and #mixed.changes == 0 and #mixed.members == 0)
end
local function test_imported_identity_preserved()
  local root, head = setup("import")
  local imported: boardtree.Claim = {id = BASE, holder = ALICE, acquired_at = NOW,
    renewed_at = NOW, expires_at = NOW + 7200, product_base = BASE}
  assert(fs.write(root .. "/claims/a", check.must(boardtree.encode_claim(imported))))
  fixture.git(root, {"add", "."}); fixture.git(root, {"commit", "-qm", "import"})
  head = check.must(refs.read_ref(root, "HEAD"))
  assert(prepare(root, head, "renew", ALICE, NOW + 1).members[1].claim_root == BASE)
end
local function test_claim_report_omits_expired_claims_and_counts_them()
  local root, head = setup("claim-report-expiry")
  assert(fs.make_dirs(root .. "/items/c"))
  assert(fs.write(root .. "/items/c/meta", "kind: task\ntitle: C\n"))
  local now = os.time()
  local function claim_for(item_id: string, expires_at: integer): boardtree.Claim
    return {id = string.rep(item_id, 40):sub(1, 40), holder = ALICE, acquired_at = expires_at - 7200,
      renewed_at = expires_at - 7200, expires_at = expires_at, product_base = BASE}
  end
  assert(fs.write(root .. "/claims/a", check.must(boardtree.encode_claim(claim_for("a", now + 7200)))))
  assert(fs.write(root .. "/claims/b", check.must(boardtree.encode_claim(claim_for("b", now - 1)))))
  assert(fs.write(root .. "/claims/c", check.must(boardtree.encode_claim(claim_for("c", now - 1)))))
  fixture.git(root, {"add", "."}); fixture.git(root, {"commit", "-qm", "mixed claims"})
  head = check.must(refs.read_ref(root, "HEAD"))
  local report = check.must(native.claim_report(root, head))
  assert(report:find("^current%-claim a status=active"), "active claim line missing: " .. report)
  assert(not report:find("current%-claim b"), "expired claim b must not be listed: " .. report)
  assert(not report:find("current%-claim c"), "expired claim c must not be listed: " .. report)
  assert(report:find("expired%-claims=2$"), "expired count missing: " .. report)
end
