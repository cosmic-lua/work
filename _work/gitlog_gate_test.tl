#!/usr/bin/env cosmic
-- The gates around `log ID --add FILE`: the claim fence every other
-- item-ref mutation runs, and what the append leaves the store holding
-- afterward. Split from `_work/gitlog_test.tl`, which sits against the
-- file cap with the append's own contract; this file is the append's
-- place among the OTHER mutations — a claimed item is its holder's to
-- move, and `--force --why` is the one audited way past that.

local check = require("cosmic.check")
local child = require("cosmic.child")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gitboard = require("_work.gitboard")
local gitlog = require("_work.gitlog")
local gitreadlog = require("_work.gitreadlog")
local store = require("_work.store")
local tail = require("_work.tail")

local init_state_repo = fixture.init_state_repo
local tmpdir = fixture.tmpdir

--- Two minted-shaped session ids: 32 lowercase hex each, what
--- `_work.claimsession.is_id` accepts and `--session` therefore needs.
local HOLDER < const > = ("a"):rep(32)
local STRANGER < const > = ("b"):rep(32)

--- Run gitboard.main(...) and capture exactly what it prints.
--- @param ... string Arguments to pass to gitboard.main, as on argv
--- @return integer gitboard.main's exit code
--- @return string Every print()'d line, newline-joined
local function gitboard_and_capture(...: string): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(gitboard.main, ...)
  _G.print = old_print
  if not ok then
    error(result, 0)
  end
  return result, table.concat(lines, "\n")
end

--- `git rev-parse SPEC` in the store, failing loudly.
--- @param s store.Store The store
--- @param spec string A rev spec
--- @return string The 40-hex object id
local function rev(s: store.Store, spec: string): string
  local r = check.must(child.run({"git", "rev-parse", spec}, {cwd = s.root}))
  assert(r.ok, spec .. ": " .. r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

--- Write one entry file under the test's own temp directory.
--- @param name string A file name
--- @param text string The entry's prose
--- @return string The path written
local function entry_file(name: string, text: string): string
  local path = fs.join(tmpdir, name)
  assert(fs.write(path, text))
  return path
end

-- A live claim fences the append the way it fences every other
-- mutation of the item's ref: a stranger's `--add` is refused and
-- writes nothing, the holder's own lands, and the stranger's
-- `--force --why` lands too, with the reason in the entry's subject
-- so the log says what was repaired. A bare `--force` is not an
-- audit and is refused before anything is read.
local function test_log_add_is_fenced_by_another_sessions_live_claim()
  local s = init_state_repo("log-gate-claim")
  local _root, leaf = fixture.root_with_leaf(s)
  local ref = "refs/heads/items/" .. leaf
  fixture.claim_item(s, leaf, HOLDER)
  local claimed_tip = rev(s, ref)

  local entry = entry_file("log-gate-stranger.md", "a stranger's observation")
  local code, printed = gitboard_and_capture("log", tail.handle(leaf),
    "--add", entry, "--session", STRANGER, "--dir", s.root)
  assert(code == 1, "a stranger's append onto a live claim: " .. printed)
  assert(printed:find("REFUSED: item is frozen by " .. HOLDER, 1, true) ~= nil,
    "the same refusal every other mutation earns: " .. printed)
  assert(rev(s, ref) == claimed_tip, "the refusal wrote nothing")

  local bare_code, bare = gitboard_and_capture("log", tail.handle(leaf),
    "--add", entry, "--session", STRANGER, "--force", "--dir", s.root)
  assert(bare_code == 1, "a bare --force is not an audit: " .. bare)
  assert(bare:find("--force needs --why", 1, true) ~= nil, bare)
  assert(rev(s, ref) == claimed_tip, "the bare force wrote nothing either")

  local own = entry_file("log-gate-holder.md", "the holder's own note")
  local own_code, own_printed = gitboard_and_capture("log", tail.handle(leaf),
    "--add", own, "--session", HOLDER, "--dir", s.root)
  assert(own_code == 0, "the holder appends freely: " .. own_printed)
  local holder_tip = rev(s, ref)
  assert(holder_tip ~= claimed_tip, "the holder's entry landed")

  local forced_code, forced = gitboard_and_capture("log", tail.handle(leaf),
    "--add", entry, "--session", STRANGER, "--force", "--why",
    "the holder asked for the measurement", "--dir", s.root)
  assert(forced_code == 0, "a stated reason is the audited way past: " .. forced)
  assert(rev(s, ref) ~= holder_tip, "the forced entry landed")

  local entries = check.must(gitreadlog.read_history(s.root, {ref}))
  local last = entries[#entries]
  assert(last.subject == ("note %s by %s (forced: the holder asked for the "
      .. "measurement)"):format(leaf:sub(1, 8), STRANGER),
    "the reason travels with the commit: " .. last.subject)
  assert(last.body == "a stranger's observation", last.body)
  assert(entries[#entries - 1].subject
    == ("note %s by %s"):format(leaf:sub(1, 8), HOLDER),
    "the holder's own subject carries no suffix: " .. entries[#entries - 1].subject)
end

-- An item nobody holds is nobody's to fence: a session with no claim
-- on it appends without force, exactly as it may `spec` it.
local function test_log_add_needs_no_force_on_an_unclaimed_item()
  local s = init_state_repo("log-gate-open")
  local _root, leaf = fixture.root_with_leaf(s)
  assert(store.close(s))
  local code, printed = gitboard_and_capture("log", tail.handle(leaf),
    "--add", entry_file("log-gate-open.md", "an open item's note"),
    "--session", STRANGER, "--dir", s.root)
  assert(code == 0, printed)
end

-- The append leaves the store's lease where the write put it, the way
-- `storewrite.save` does: the leased sha is the entry's own commit and
-- the one-shot resolve ticket is spent, so a later write through the
-- same handle leases against the tip that is actually there.
local function test_log_add_advances_the_stores_lease()
  local s = init_state_repo("log-gate-lease")
  local _root, leaf = fixture.root_with_leaf(s)
  local ref = "refs/heads/items/" .. leaf
  local _it = check.must(store.load(s, leaf))
  local before = s.leased_sha[leaf]
  assert(store.close(s))
  local code = gitlog.cmd_log_add(s, leaf,
    entry_file("log-gate-lease.md", "what moved the lease"), HOLDER)
  assert(code == 0, "the append")
  local after = rev(s, ref)
  assert(after ~= before, "the ref moved")
  assert(s.leased_sha[leaf] == after,
    ("the lease is the entry's commit: %s vs %s"):format(
      tostring(s.leased_sha[leaf]), after))
  assert(s.leased_item[leaf] ~= nil and s.leased_item[leaf].id == leaf,
    "the observed snapshot is still held")
  assert(s.fresh_lease == "", "the one-shot resolve ticket is spent")
  assert(s.written_at > 0, "the write's own second is recorded")
end

-- Draft selection is uniform across mutations, and `--add` is one: the
-- flag parses and reaches draft activation, so an unknown draft is the
-- verb's own refusal rather than an unknown option.
local function test_log_add_accepts_draft_selection()
  local s = init_state_repo("log-gate-draft")
  local _root, leaf = fixture.root_with_leaf(s)
  assert(store.close(s))
  local code, printed = gitboard_and_capture("log", tail.handle(leaf),
    "--add", entry_file("log-gate-draft.md", "under a draft"),
    "--session", HOLDER, "--draft", ("0"):rep(27), "--dir", s.root)
  assert(code == 1, printed)
  assert(printed:find("gitboard-log: REFUSED:", 1, true) ~= nil,
    "the flag parsed and the draft was looked for: " .. printed)
end
