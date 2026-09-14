#!/usr/bin/env cosmic
local check = require("cosmic.check")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local fastimport = require("_work.fastimport")
local source = require("_work.migrate6_source")
local migrate = require("_work.migrate6")
local boardread = require("_work.boardread")
local history = require("_work.boardhistory")
local diagnostics = require("_work.migrate6_diagnostics")

local function test_migration_preserves_prose_and_empty_attribution_without_fake_notes()
  local root = fs.join(fixture.tmpdir, "migrate6-prose")
  assert(fs.remove_all(root)); assert(fs.make_dirs(root)); fixture.git(root, {"init", "-q"})
  local id = "3HyRcW05wBip6Wqcz145bUQBTyj"
  local ref = "refs/heads/items/" .. id
  local messages = {"new a", "migrate a", "log a\n\nActual note.\n\nParagraph: useful prose",
    "log a\n\nSecond note.\n\nClaim-Batch: retired-batch", "import a"}
  local ops = {"new", "migrate", "log", "log", "import"}
  local plans: {fastimport.CommitPlan} = {}
  for n, message in ipairs(messages) do
    plans[#plans + 1] = {ref = ref, from = n == 1 and "" or ":" .. tostring(n - 1),
      mark = ":" .. tostring(n), author_name = "author", author_email = "author@test",
      author_date = "1700000000 +0000", committer_name = "gitboard", committer_email = "gitboard@test",
      committer_date = "1700000000 +0000", message = message, op = ops[n],
      ops = n == 1 and {{path = "meta", content = "title: a\nresult: legacy-digest\n"}} or {}}
  end
  assert(fastimport.run(root, plans))
  local cp = check.must(migrate.run(root))
  local view = check.must(boardread.list(root, cp.head))
  local visible, empty = 0, 0
  local bodies: {string: boolean} = {}
  for _, body in pairs(view.logs_by_id[id]) do visible = visible + 1; bodies[body] = true end
  for _, body in pairs(view.raw_logs_by_id[id]) do if body == "" then empty = empty + 1 end end
  assert(visible == 2 and empty == 2, "administrative noops remain attributed but are not notes")
  assert(bodies["Actual note.\n\nParagraph: useful prose"] and bodies["Second note."], "legacy prose semantics are exact")
  local walk = check.must(history.read(root, cp.head))
  assert(#walk.events_by_id[id] == 5, "every source event retains item attribution")
  local old_tip = check.must(source.git(root, {"rev-parse", ref})):gsub("%s+$", "")
  assert(walk.tip_by_id[id] == cp.marks[old_tip], "administrative final event remains the item tip")
  local report = check.must(diagnostics.inspect(root, cp.head, cp.marks))
  assert(report.count == 1 and report.results[id] == "legacy-digest", "unmapped results must be named")
end
