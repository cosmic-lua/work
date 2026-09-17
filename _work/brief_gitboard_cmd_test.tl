#!/usr/bin/env cosmic
-- `brief --gitboard-command`/`--gitboard-cwd`, exercised end to end through
-- `gitboard.main`: the caller's own exact invocation is accepted — for a
-- builder or a reviewer, either with no receipt in play — and carried as a
-- brief fact, but no brief body renders it: a reviewer reports a verdict
-- envelope and a builder a commit id, and the caller runs the board verb.
-- The fixture models the real shape: an APE run through `sh`, at an
-- absolute path outside the product worktree, invoked from a cwd also
-- outside that worktree.

local check = require("cosmic.check")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local product_fixture = require("_work.brief_product_fixture")
local gitboard = require("_work.gitboard")
local gitinvocation = require("_work.gitinvocation")
local item = require("_work.item")
local store = require("_work.store")

local BASE < const > = ("a"):rep(40)
local HEAD = ("b"):rep(40)

local TMP < const > = os.getenv("TEST_TMPDIR") or "/tmp"
-- The absolute board executable: outside the product worktree, shaped like
-- the real `<board-root>/o/bin/gitboard` the evidence names.
local BOARD_APE < const > = fs.join(TMP, "toolroot/o/bin/gitboard")
-- The board cwd the caller ran it from: a distinct directory, also outside
-- the product worktree.
local BOARD_CWD < const > = fs.join(TMP, "orchestrator-run")
-- A stand-in product worktree, never itself referenced by the invocation —
-- proof that the fixture's board executable and cwd genuinely sit outside it.
local PRODUCT_WORKTREE < const > = fs.join(TMP, "brief-gitboard-cmd-product-worktree")
assert(fs.make_dirs(fs.dirname(BOARD_APE)) and fs.write(BOARD_APE, "#!/bin/sh\nexit 0\n"))
assert(fs.set_mode(BOARD_APE, tonumber("755", 8)))
assert(fs.make_dirs(BOARD_CWD))
assert(fs.make_dirs(PRODUCT_WORKTREE))
local COMMAND < const > = "sh " .. BOARD_APE

--- `it.claim`/`it.claim_base` are projected from a claim-batch pointer at
--- read time (`_work.claimprojection`), never from the item's own history,
--- so the real claim comes from `fixture.claim_item` rather than a direct
--- field assignment.
local function handover(s: store.Store, id: string)
  fixture.claim_item(s, id, "session-a", BASE)
  local it = check.must(store.load(s, id))
  it.repo = "acme/widgets"
  HEAD = product_fixture.prepare(s, it)
  assert(item.record_involvement(it.builders, "session-a"))
  fixture.raw_seed_item(s, it,
    ("take %s by session-a head:%s"):format(id:sub(1, 8), HEAD:sub(1, 12)))
end

--- Move `id`'s claim from the builder to the reviewing session named by
--- `session` — the step the orchestrator takes between a builder's
--- handover and `brief review ID`. A review now refuses outright when the
--- item has no active claim or when the claim belongs to its own
--- builders, so a fresh reviewing claim is required here to reach the
--- rendering behavior these tests exercise.
local function reclaim(s: store.Store, id: string, session: string)
  fixture.drop_claim(s, id, "session-a", "handed over")
  fixture.claim_item(s, id, session, BASE)
end

local function capture(f: function(): integer): integer, string
  local old = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, code = pcall(f)
  _G.print = old
  if not ok then error(code, 0) end
  return code, table.concat(lines, "\n")
end

local function test_review_accepts_the_caller_invocation_and_never_renders_it()
  local s = fixture.init_state_repo("brief-gitboard-cmd-review")
  local _, leaf = fixture.root_with_leaf(s)
  fixture.give_spec(s, leaf)
  handover(s, leaf)
  reclaim(s, leaf, "f00dcafe00001234dead")
  check.must(env.set("GITBOARD_SESSION", "f00dcafe00001234dead"))
  local code, out = capture(function(): integer
      return gitboard.main("brief", "review", leaf, "--dir", s.root,
        "--gitboard-command", COMMAND, "--gitboard-cwd", BOARD_CWD)
    end)
  assert(env.unset("GITBOARD_SESSION"))
  assert(code == 0, out)
  assert(out:find(COMMAND, 1, true) == nil and out:find(BOARD_CWD, 1, true) == nil,
    "the caller's invocation is accepted but never rendered in the body: " .. out)
  assert(out:find("verdict " .. leaf, 1, true) == nil,
    "no verdict command line renders for the reviewer to run: " .. out)
  assert(out:find("verdict: accept|request-changes|reject head=" .. HEAD
      .. " session=f00dcafe00001234dead", 1, true) ~= nil,
    "the reviewer reports the verdict envelope for the caller to record: " .. out)
  assert(out:find("cd <PRODUCT_ROOT>", 1, true) == nil,
    "no guessed product-checkout bootstrap cd survives: " .. out)
  assert(out:find(gitinvocation.UNRESOLVED, 1, true) == nil,
    "nothing renders the unresolved sentinel: " .. out)
  assert(out:find(PRODUCT_WORKTREE, 1, true) == nil,
    "the brief never references the (unrelated) product worktree: " .. out)
end

local function test_review_with_no_caller_command_renders_no_sentinel()
  local s = fixture.init_state_repo("brief-gitboard-cmd-unresolved")
  local _, leaf = fixture.root_with_leaf(s)
  fixture.give_spec(s, leaf)
  handover(s, leaf)
  reclaim(s, leaf, "f00dcafe00002468dead")
  check.must(env.set("GITBOARD_SESSION", "f00dcafe00002468dead"))
  local code, out = capture(function(): integer
      return gitboard.main("brief", "review", leaf, "--dir", s.root)
    end)
  assert(env.unset("GITBOARD_SESSION"))
  assert(code == 0, out)
  assert(out:find(gitinvocation.UNRESOLVED, 1, true) == nil,
    "no caller command was given, and no brief body renders the sentinel: " .. out)
  assert(out:find("verdict " .. leaf, 1, true) == nil
    and out:find("verdict: accept|request-changes|reject head=" .. HEAD, 1, true) ~= nil,
    "the envelope replaces every verdict command line: " .. out)
  assert(out:find("bin/gitboard", 1, true) == nil,
    "and never a guessed product-checkout bin/gitboard: " .. out)
  assert(out:find("cd <PRODUCT_ROOT>", 1, true) == nil,
    "nor a product-checkout bootstrap: " .. out)
end

local function test_builder_direct_flags_are_accepted_and_never_rendered()
  local s = fixture.init_state_repo("brief-gitboard-cmd-builder")
  local _, leaf = fixture.root_with_leaf(s)
  fixture.give_spec(s, leaf)
  local code, out = capture(function(): integer
      return gitboard.main("brief", "builder", leaf, "--dir", s.root,
        "--gitboard-command", COMMAND, "--gitboard-cwd", BOARD_CWD)
    end)
  assert(code == 0, out)
  assert(out:find(COMMAND, 1, true) == nil
    and out:find(gitinvocation.UNRESOLVED, 1, true) == nil,
    "a builder brief renders neither the invocation nor the sentinel: " .. out)
  assert(out:find("`take " .. leaf .. " --head SHA [--url URL]` itself", 1, true) ~= nil,
    "the builder reports the commit id; the caller runs take: " .. out)
end

local function test_gitboard_command_and_cwd_are_refused_alone()
  local s = fixture.init_state_repo("brief-gitboard-cmd-refusal")
  local _, leaf = fixture.root_with_leaf(s)
  fixture.give_spec(s, leaf)
  local code, out = capture(function(): integer
      return gitboard.main("brief", "builder", leaf, "--dir", s.root,
        "--gitboard-command", COMMAND)
    end)
  assert(code ~= 0, "one flag without the other is refused, never guessed: " .. out)
  assert(out:find("--gitboard-command and --gitboard-cwd must be supplied together",
      1, true) ~= nil, out)
  local code2, out2 = capture(function(): integer
      return gitboard.main("brief", "builder", leaf, "--dir", s.root,
        "--gitboard-cwd", BOARD_CWD)
    end)
  assert(code2 ~= 0, "the reverse omission is refused too: " .. out2)
end
