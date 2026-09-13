#!/usr/bin/env cosmic
local check = require("cosmic.check")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local gitobj = require("_work.gitobj")
local stateread_fsck = require("_work.stateread_fsck")

local function test_native_fsck_reports_actual_format_and_validates_marks()
  local root = fs.join(os.getenv("TEST_TMPDIR") or "/tmp", "stateread-fsck-native")
  assert(fs.remove_all(root) and fs.make_dirs(root))
  assert(check.must(child.run({"git", "init", "-q", root})).ok)
  local format = check.must(gitobj.hash_object_write(root, "format-six-sentinel\n"))
  local marks = check.must(gitobj.hash_object_write(root, "not a literal\n"))
  local migration = check.must(gitobj.mktree_write(root,
      {{mode = "100644", otype = "blob", sha = marks, name = "marks"}}))
  local tree = check.must(gitobj.mktree_write(root, {
        {mode = "100644", otype = "blob", sha = format, name = "format"},
        {mode = "40000", otype = "tree", sha = migration, name = "migration"}}))
  local head = check.must(gitobj.commit_tree(root, {tree = tree, parents = {}, message = "sentinel",
        author_name = "test", author_email = "test@board", committer_name = "test",
        committer_email = "test@board", author_date = "1700000000 +0000",
        committer_date = "1700000000 +0000", op = ""}))
  local problems = stateread_fsck.problems(root, head)
  assert(#problems == 2, table.concat(problems, "\n"))
  local joined = table.concat(problems, "\n")
  assert(joined:find('format%-six%-sentinel\\n'))
  assert(joined:find('expected canonical "6\\n"', 1, true))
  assert(joined:find("migration/marks:", 1, true))
end
