#!/usr/bin/env cosmic
-- The compatibility facade owns selection and presentation of native draft
-- receipts. Statewrite tests own transition chaining and publication.
local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local gitdraft = require("_work.gitdraft")
local refs = require("_work.refs")
local staging = require("_work.statestaging")
local store = require("_work.store")
local write = require("_work.storewrite")
local publish = require("_work.publish")

local function stage_title(root: string, id: string, title: string)
  local s = check.must(store.open(root))
  local it = check.must(store.load(s, id))
  it.title = title
  assert(write.save(s, it, "draft title"))
  assert(publish.publish(s))
  assert(store.close(s))
end

local function test_begin_activate_plan_and_deactivate()
  local s = fixture.init_state_repo("draft-facade")
  local id = fixture.file_item(s, "before draft", "")
  local canonical = s.state_head
  local draft = check.must(gitdraft.begin(s.root))
  assert(draft.native.kind == "draft" and draft.native.base == canonical)
  assert(#gitdraft.plan(draft) == 0)
  assert(gitdraft.active(s.root) == nil)

  assert(gitdraft.activate(s.root, draft))
  assert(check.must(gitdraft.active(s.root)).id == draft.id)
  stage_title(s.root, id, "inside draft")
  local reopened = check.must(gitdraft.open(s.root, draft.id))
  local plan = gitdraft.plan(reopened)
  assert(#plan == 1 and plan[1].ref == "refs/heads/state")
  assert(plan[1].expected == canonical and plan[1].next == reopened.native.tip)
  assert(check.must(refs.read_ref(s.root, "refs/heads/state")) == canonical,
    "draft work must not move canonical state")

  gitdraft.deactivate(s.root)
  assert(gitdraft.active(s.root) == nil and staging.active(s.root) == nil)
  local canonical_store = check.must(store.open(s.root))
  assert(check.must(store.load(canonical_store, id)).title == "before draft")
end

local function test_open_list_gc_and_abort_preserve_the_native_receipt()
  local s = fixture.init_state_repo("draft-durable")
  local id = fixture.file_item(s, "durable draft", "")
  local draft = check.must(gitdraft.begin(s.root))
  assert(gitdraft.activate(s.root, draft))
  stage_title(s.root, id, "retained through gc")
  gitdraft.deactivate(s.root)

  local reopened = check.must(gitdraft.open(s.root, draft.staging_ref))
  local all = check.must(gitdraft.list(s.root))
  assert(#all == 1 and all[1].id == draft.id)
  assert(reopened.native.tip ~= reopened.native.base)
  local gc = check.must(child.run({"git", "reflog", "expire", "--expire=now",
        "--all"}, {cwd = s.root}))
  assert(gc.ok, gc.stderr)
  gc = check.must(child.run({"git", "gc", "--prune=now"}, {cwd = s.root}))
  assert(gc.ok, gc.stderr)
  local exists = check.must(child.run({"git", "cat-file", "-e",
        reopened.native.tip .. "^{commit}"}, {cwd = s.root}))
  assert(exists.ok, "draft receipt must retain its speculative tip")
  assert(gitdraft.abort(s.root, check.must(gitdraft.open(s.root, draft.id))))
  assert(#check.must(gitdraft.list(s.root)) == 0)
  assert(check.must(refs.read_ref(s.root, draft.staging_ref)) == refs.ZERO_SHA)
end

local function test_activation_refuses_a_changed_destination()
  local s = fixture.init_state_repo("draft-destination")
  local draft = check.must(gitdraft.begin(s.root))
  assert(refs.set_board_mode(s.root, "remote"))
  local ok, err = gitdraft.activate(s.root, draft)
  assert(not ok and err:find("destination differs", 1, true), err)
  assert(gitdraft.active(s.root) == nil)
end
