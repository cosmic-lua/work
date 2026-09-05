#!/usr/bin/env cosmic
-- `_work.gitbatch`'s `BatchSession`: a `git cat-file --batch` process
-- fed successive rounds of queries, each round itself pipelined in
-- bounded chunks so neither a large round (many queries) nor a slow
-- one (one query at a time) can deadlock or crawl. `_work.gitobj`'s
-- differential tests cover `hash_object`/`mktree` against real git;
-- this file is the session mechanics alone.

local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local gitbatch = require("_work.gitbatch")
local gitobj = require("_work.gitobj")
local proc = require("cosmic.proc")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"

local hermetic_config < const > = fs.join(tmpdir, "gitconfig-empty")
assert(fs.write(hermetic_config, ""))
assert(env.set("GIT_CONFIG_GLOBAL", hermetic_config))
assert(env.set("GIT_CONFIG_NOSYSTEM", "1"))

--- A scratch git repository with nothing in it yet.
local function fresh_repo(name: string): string
  local root = fs.join(tmpdir, "gitbatch-" .. name)
  assert(fs.remove_all(root))
  assert(fs.make_dirs(root))
  local r = check.must(child.run({"git", "init", "-q", root}))
  assert(r.ok, "git init failed: " .. r.stderr)
  return root
end

-- A session answers dependent rounds over the SAME process: the
-- second round's query can be exactly a sha the first round's answer
-- named (a tree entry's own blob), and both rounds resolve correctly.
local function test_batch_session_answers_two_dependent_rounds()
  local root = fresh_repo("two-rounds")
  local leaf = check.must(gitobj.hash_object_write(root, "leaf content"))
  local tree = check.must(gitobj.mktree_write(root,
      {{mode = "100644", otype = "blob", sha = leaf, name = "f"}}))
  local sess = check.must(gitbatch.batch_session(root))
  local round1 = check.must(sess:request({tree}))
  local entries = gitobj.parse_tree(round1[tree].content)
  assert(#entries == 1 and entries[1].sha == leaf, "round 1: the tree's own entry")
  local round2 = check.must(sess:request({entries[1].sha}))
  assert(round2[leaf].content == "leaf content", "round 2: the entry's blob")
  assert(check.must(sess:close()))
end

-- A missing sha in one round (git's own `<sha> missing` line) is
-- simply absent from that round's answer and does not desync the
-- rounds after it — the next round still answers against its own
-- queries, not a stream shifted by the missing line's absent body.
local function test_batch_session_missing_sha_does_not_break_later_rounds()
  local root = fresh_repo("missing")
  local blob = check.must(gitobj.hash_object_write(root, "present"))
  local sess = check.must(gitbatch.batch_session(root))
  local round1 = check.must(sess:request(
      {blob, "0000000000000000000000000000000000000000"}))
  assert(round1[blob].content == "present", "round 1: the present blob")
  assert(round1["0000000000000000000000000000000000000000"] == nil,
    "round 1: the missing sha is absent")
  local round2 = check.must(sess:request({blob}))
  assert(round2[blob].content == "present", "round 2: unaffected by round 1's miss")
  assert(check.must(sess:close()))
end

-- A round larger than one chunk: the pipelining must cross a chunk
-- boundary and keep answering correctly, in query order, rather than
-- stalling (the whole-round-up-front deadlock) or losing track past
-- the first chunk (an off-by-one in the chunk loop).
local function test_batch_session_answers_a_round_larger_than_one_chunk()
  local root = fresh_repo("many-queries")
  local n = 200 -- several times gitbatch's own chunk size
  local shas: {string} = {}
  for i = 1, n do
    shas[i] = check.must(gitobj.hash_object_write(root, "item " .. tostring(i)))
  end
  local sess = check.must(gitbatch.batch_session(root))
  local out = check.must(sess:request(shas))
  for i = 1, n do
    local entry = out[shas[i]]
    assert(entry ~= nil, "entry " .. i .. " is present")
    assert(entry.content == "item " .. tostring(i), "entry " .. i .. " has its own content")
  end
  assert(check.must(sess:close()))
end

-- A round whose request bytes AND answer bytes both exceed a pipe's
-- 64KB buffer is the actual hazard chunking guards against — a large
-- COUNT of tiny queries (the round-larger-than-one-chunk test above)
-- never fills either pipe on its own, and passes even with chunking
-- disabled. Run in a bounded, throwaway subprocess: a regression here
-- is exactly the shape that hangs indefinitely rather than answering
-- wrong, so `timeout` turns that into a failed assertion within
-- seconds instead of a stuck suite.
local function test_batch_session_answers_a_pipe_saturating_round()
  local root = fresh_repo("pipe-saturating")
  local payload = ("y"):rep(2000)
  local sha = check.must(gitobj.hash_object_write(root, payload))
  local n = 12000 -- request lines alone: 12000 * 41 bytes =~ 490 KB
  local exe = check.must(proc.interpreter())
  local script = ([[
    local gitbatch = require("_work.gitbatch")
    local sess = assert(gitbatch.batch_session(%q))
    local queries = {}
    for i = 1, %d do queries[i] = %q end
    local out = assert(sess:request(queries))
    local entry = out[%q]
    if entry == nil or entry.content ~= %q then
      os.exit(1)
    end
    assert(sess:close())
    os.exit(0)
  ]]):format(root, n, sha, sha, payload)
  local r = check.must(child.run({"timeout", "-k", "5", "20", exe, "-e", script}))
  assert(r.ok, "a pipe-saturating round must answer within 20s, not deadlock: code="
    .. tostring(r.code) .. " stderr=" .. tostring(r.stderr))
end

-- `close` is safe after a failed `request` — the shape every
-- early-return-on-error caller (`_work.gitread.load`/`.list`,
-- `_work.gitreadmany.load_many`) relies on. Killing the process out
-- from under the session (the same `stop` every `cosmic.child` caller
-- uses to simulate a dead child) makes the next `request` fail;
-- `close` afterward must still reap cleanly rather than hang.
local function test_batch_session_close_after_error_is_safe()
  local root = fresh_repo("close-after-error")
  local sess = check.must(gitbatch.batch_session(root))
  assert(check.must(sess._handle:stop()))
  local _r = sess._handle:wait()
  local out, err = sess:request({"deadbeef"})
  assert(out == nil, "a request against a killed process must fail")
  assert(err ~= nil and err ~= "", "an error message")
  local ok, cerr = sess:close()
  assert(ok == true, "close after a failed request must still succeed: " .. tostring(cerr))
end
