#!/usr/bin/env cosmic
local check = require("cosmic.check")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local git = require("_work.singlehead_git")
local literal = require("_work.singlehead_literal")
local objects = require("_work.stateplan_objects")
local projection = require("_work.stateplan_git")
local protocol = require("_work.snapshot_protocol")
local snapshot = require("_work.snapshot")
local tx = require("_work.statetransaction")

local ZERO < const > = string.rep("0", 40)
local AUTHOR: tx.Author = {name = "Session", email = "session@example.test",
  date = "1700000000 +0000"}

local function message(subject: string): string
  local encoded = check.must(literal.encode(AUTHOR)):gsub("\n$", "")
  return subject .. "\n\nGitboard-Author: " .. encoded .. "\n"
end

local function repo(name: string, count?: integer): string, string
  local root = fs.join(fixture.tmpdir, "snapshot-" .. name)
  assert(fs.remove_all(root)); assert(fs.make_dirs(root))
  check.must(git.run(root, {"init", "--quiet"}))
  local leaves: {objects.TreeElement} = {}
  for index = 1, count or 0 do
    leaves[#leaves + 1] = {path = ("untouched-%03d"):format(index),
      mode = "100644", otype = "blob", content = tostring(index)}
  end
  local tree = check.must(objects.make_tree(root, leaves))
  return root, check.must(objects.make_commit(root, tree, "base\n"))
end

local function destination(suffix?: string): snapshot.Destination
  return {repository = "example/board", branch = "state", remote = "origin",
    target_url = "https://github.com/example/board.git" .. (suffix or "")}
end

local function commit(root: string, parent: string, path: string,
    content: string, subject?: string): string
  local change: tx.Change = {path = path, mode = "100644", content = content,
    delete = false}
  local tree = check.must(projection.apply(root, parent, {change}))
  return check.must(git.text(root, {"commit-tree", tree, "-p", parent},
      message(subject or "update board"), {
        GIT_AUTHOR_NAME = AUTHOR.name, GIT_AUTHOR_EMAIL = AUTHOR.email,
        GIT_AUTHOR_DATE = AUTHOR.date, GIT_COMMITTER_NAME = "gitboard",
        GIT_COMMITTER_EMAIL = "gitboard@localhost", GIT_COMMITTER_DATE = AUTHOR.date}))
end

local function accept(_root: string, _parent: string,
    _commit: string): integer | nil, string
  return 200, ""
end

local function test_capture_requires_validation_and_rejects_merges()
  local root, base = repo("capture")
  local candidate = commit(root, base, "items-a", "one")
  local called = false
  local function reject(_root: string, _parent: string,
      _commit: string): integer | nil, string
    called = true
    return nil, "board rule refused arbitrary write"
  end
  local refused, err = snapshot.capture(root, candidate, destination(), reject)
  assert(called and refused == nil and err:find("board rule", 1, true), err)
  local plan = check.must(snapshot.capture(root, candidate, destination(), accept))
  assert(plan.parent == base and plan.publish_by == 200)
  local other = commit(root, base, "other", "side")
  local merge = check.must(git.text(root, {"commit-tree", plan.tree, "-p", base,
        "-p", other}, message("merge"), {
        GIT_AUTHOR_NAME = AUTHOR.name, GIT_AUTHOR_EMAIL = AUTHOR.email,
        GIT_AUTHOR_DATE = AUTHOR.date, GIT_COMMITTER_NAME = "gitboard",
        GIT_COMMITTER_EMAIL = "gitboard@localhost", GIT_COMMITTER_DATE = AUTHOR.date}))
  local merged, merr = snapshot.capture(root, merge, destination(), accept)
  assert(merged == nil and merr:find("exactly one parent", 1, true), merr)
end
test_capture_requires_validation_and_rejects_merges()

local function test_capture_rejects_a_malformed_logical_author_date()
  local root, base = repo("malformed-author-date")
  local tree = check.must(projection.apply(root, base,
      {{path = "item", mode = "100644", content = "changed", delete = false}}))
  local malformed = check.must(literal.encode({name = AUTHOR.name,
        email = AUTHOR.email, date = "nonsense"})):gsub("\n$", "")
  local candidate = check.must(git.text(root, {"commit-tree", tree, "-p", base},
      "bad date\n\nGitboard-Author: " .. malformed .. "\n", {
        GIT_AUTHOR_NAME = AUTHOR.name, GIT_AUTHOR_EMAIL = AUTHOR.email,
        GIT_AUTHOR_DATE = AUTHOR.date, GIT_COMMITTER_NAME = "gitboard",
        GIT_COMMITTER_EMAIL = "gitboard@localhost", GIT_COMMITTER_DATE = AUTHOR.date}))
  local identity, err = snapshot.commit_identity(root, candidate)
  assert(identity == nil and err:find("logical author", 1, true), err)
end
test_capture_rejects_a_malformed_logical_author_date()

local function test_small_large_board_snapshot_is_exactly_three_calls()
  local root, base = repo("large", 120)
  local candidate = commit(root, base, "changed", "new")
  local plan = check.must(snapshot.capture(root, candidate, destination(), accept))
  local calls = check.must(protocol.calls(plan))
  assert(#calls == 3 and calls[1].tool == "github_create_tree"
    and calls[2].tool == "github_create_commit"
    and calls[3].tool == "github_update_ref")
  assert(not plan.complete_tree and #plan.entries == 1
    and plan.entries[1].path == "changed",
    "untouched leaves must not enter the connector payload")
  assert(calls[1].arguments.base_tree_sha == plan.base_tree)
  assert(calls[2].arguments.parent_sha == base
    and calls[2].arguments.message == plan.message)
  assert(protocol.commit_call(plan, plan.tree))
  local wrong_commit, tree_err = protocol.commit_call(plan, plan.base_tree)
  assert(wrong_commit == nil and tree_err:find("different", 1, true), tree_err)
  assert(calls[3].arguments.force == false)
end
test_small_large_board_snapshot_is_exactly_three_calls()

local function test_delete_uses_complete_tree_and_shell_whole_head_gate()
  local root, base = repo("delete", 3)
  local change: tx.Change = {path = "untouched-002", mode = "100644",
    content = "", delete = true}
  local tree = check.must(projection.apply(root, base, {change}))
  local candidate = check.must(git.text(root, {"commit-tree", tree, "-p", base},
      message("delete one"), {GIT_AUTHOR_NAME = AUTHOR.name,
        GIT_AUTHOR_EMAIL = AUTHOR.email, GIT_AUTHOR_DATE = AUTHOR.date,
        GIT_COMMITTER_NAME = "gitboard", GIT_COMMITTER_EMAIL = "gitboard@localhost",
        GIT_COMMITTER_DATE = AUTHOR.date}))
  local plan = check.must(snapshot.capture(root, candidate, destination(), accept))
  local calls = check.must(protocol.calls(plan))
  assert(plan.complete_tree and #plan.entries == 2
    and calls[1].arguments.base_tree_sha == nil)
  assert(protocol.shell_candidate(root, plan, base, 199) == candidate)
  local moved = commit(root, base, "disjoint", "advance")
  local stale, serr = protocol.shell_candidate(root, plan, moved, 199)
  assert(stale == nil and serr:find("conflicts", 1, true), serr)
  local expired, eerr = protocol.shell_candidate(root, plan, base, 200)
  assert(expired == nil and eerr:find("expired", 1, true), eerr)
end
test_delete_uses_complete_tree_and_shell_whole_head_gate()

local function frozen_message(subject: string, author?: tx.Author): string
  local encoded = check.must(literal.encode(author or AUTHOR)):gsub("\n$", "")
  return subject .. "\n\nTransaction: snapshot-collapse\nGitboard-Author: "
  .. encoded .. "\n"
end

local function transition(base: string, path: string, content: string,
    dependency: string): tx.Transition
  return {base = base, dependencies = {{path = path, id = dependency}},
    changes = {{path = path, mode = "100644", content = content, delete = false}},
    message = frozen_message("intermediate " .. content),
    author = {name = AUTHOR.name, email = AUTHOR.email, date = AUTHOR.date},
    publish_by = 0, bounded = false, gate = ""}
end

local function test_multi_transition_collapse_is_one_ordinary_commit()
  local root, base = repo("collapse")
  local first = transition(base, "item", "one", ZERO)
  local staged_tree = check.must(projection.apply(root, base, first.changes))
  local staged = check.must(projection.commit(root, base, staged_tree, first))
  local second = transition(staged, "item", "two",
    check.must(projection.path_id(root, staged, "item")))
  second.author.date = "1700000010 +0000"
  second.message = frozen_message("intermediate two", second.author)
  local frozen: tx.Frozen = {format = tx.FORMAT, repository = "example/board",
    branch = "state", remote = "origin", transaction = "snapshot-collapse",
    staging_sha = base, transitions = {first, second}}
  local plan = check.must(snapshot.collapse(root, frozen, base,
      "https://github.com/example/board.git", "update item twice", nil, 100))
  assert(plan.parent == base and plan.local_commit ~= staged
    and check.must(git.oid(root, plan.local_commit .. "^")) == base)
  assert(plan.author.date == second.author.date,
    "the final operation instant authors a multi-command snapshot")
  assert(check.must(git.run(root, {"show", "-s", "--format=%B",
          plan.local_commit})):find("Transaction:", 1, true) == nil)
  assert(#check.must(protocol.calls(plan)) == 3)
  local final = check.must(git.run(root, {"show", plan.local_commit .. ":item"}))
  assert(final == "two")
end
test_multi_transition_collapse_is_one_ordinary_commit()
