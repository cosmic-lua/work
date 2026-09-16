--- Real local commits for brief tests that exercise prose, not Git history.
local check = require("cosmic.check")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local item = require("_work.item")
local repository_map = require("_work.repository_map")
local store = require("_work.store")

local function prepare(s: store.Store, it: item.Item): string
  local root = repository_map.resolve(s.root, it.repo or "", "")
  if root == nil then
    root = fs.join(fixture.tmpdir, "brief-product-fixture-" .. it.id)
    assert(fs.remove_all(root) and fs.make_dirs(root))
    fixture.git(root, {"init", "-q"})
    fixture.git(root, {"commit", "--allow-empty", "-qm", "product"})
    assert(repository_map.resolve(s.root, it.repo or "", root))
  end
  fixture.git(root, {"commit", "--allow-empty", "-qm", "reviewable product"})
  local r = check.must(child.run({"git", "rev-parse", "HEAD"}, {cwd = root}))
  assert(r.ok, r.stderr)
  local sha = r.stdout:gsub("%s+$", "")
  it.base, it.handover_head = sha, sha
  return sha
end

local record brief_product_fixture
  prepare: function(s: store.Store, it: item.Item): string
end
local M: brief_product_fixture = {prepare = prepare}
return M
