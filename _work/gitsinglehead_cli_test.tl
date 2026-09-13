#!/usr/bin/env cosmic
--- End-to-end native CLI coverage for draft/log transport and the complete
--- take/renew/drop claim lifecycle. Connector calls are materialized locally;
--- no provider or network is contacted.
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local gitboard = require("_work.gitboard")
local objects = require("_work.singlehead_objects")
local plans = require("_work.singlehead_plan")
local literal = require("_work.singlehead_literal")
local refs = require("_work.refs")

local tmp = assert(os.getenv("TEST_TMPDIR"))
local board = fs.join(tmp, "board")
assert(fs.make_dirs(board))
local command_count = 0

local function command(argv: {string}, expected?: integer): string
  local full: {string} = {}
  for _, word in ipairs(argv) do full[#full + 1] = word end
  full[#full + 1] = "--dir"
  full[#full + 1] = board
  command_count = command_count + 1
  local stdout_path = fs.join(tmp, "command-" .. tostring(command_count) .. ".out")
  local stderr_path = fs.join(tmp, "command-" .. tostring(command_count) .. ".err")
  local stdout, stderr = assert(io.open(stdout_path, "w")),
  assert(io.open(stderr_path, "w"))
  local old_print, old_stdout, old_stderr = _G.print, io.stdout, io.stderr
  io.stdout, io.stderr = stdout, stderr
  _G.print = function(...: any)
    local parts: {string} = {}
    for index = 1, select("#", ...) do
      parts[index] = tostring((select(index, ...)))
    end
    stdout:write(table.concat(parts, "\t"), "\n")
  end
  local ok, code = pcall(function(): integer
      return gitboard.main(table.unpack(full))
    end)
  stdout:flush()
  stderr:flush()
  stdout:close()
  stderr:close()
  _G.print, io.stdout, io.stderr = old_print, old_stdout, old_stderr
  if not ok then error(code, 0) end
  local output = assert(fs.read(stdout_path)) .. assert(fs.read(stderr_path))
  assert(code == (expected or 0), output)
  return output
end

local function git(argv: {string}, cwd?: string): string
  local full: {string} = {"git", "--no-replace-objects"}
  for _, word in ipairs(argv) do full[#full + 1] = word end
  local r, err = child.run(full, {cwd = cwd or board})
  assert(r ~= nil and r.ok, err ~= "" and err or r and r.stderr or "git failed")
  return (r.stdout:gsub("%s+$", ""))
end

local function only_ref(pattern: string): string
  local out = git({"for-each-ref", "--format=%(refname)", pattern})
  assert(out ~= "" and out:find("\n", 1, true) == nil, out)
  return out
end

local function publish_local(staging_ref: string, name: string): string
  local path = fs.join(tmp, name .. ".literal")
  local output = command({"single-head", "publish-plan", staging_ref,
      "--out", path})
  assert(output:find('status="ready"', 1, true), output)
  local call = command({"single-head", "call", "--plan", path,
      "--call-index", "0"})
  assert(call:find("github_create_tree", 1, true), call)
  local decoded = literal.decode_object(call) as {string: any} -- cast: call table
  local arguments = decoded.arguments as {string: any} -- cast: connector call schema
  local elements = arguments.tree_elements as {{string: any}} -- cast: create-tree call
  assert(#elements > 0)
  assert(elements[1]["type"] == "blob")
  assert(elements[1].otype == nil, "saved plan leaked internal otype field")
  local plan, perr = plans.load(path)
  assert(plan ~= nil, perr)
  local head, herr = plans.local_candidate(board, plan)
  assert(head ~= nil, herr)
  local before = assert(refs.read_ref(board, "refs/remotes/origin/envelope-poc"))
  assert(refs.update_ref(board, "refs/remotes/origin/envelope-poc", head,
      before))
  return head
end

local function bootstrap(): string
  local help = command({"help", "single-head"})
  assert(not help:lower():find("python", 1, true), help)
  assert(not help:find("--helper", 1, true), help)
  assert(help:find("PLAN.literal", 1, true), help)
  command({"init", "--local"})
  command({"new", "native single-head item"})
  command({"new", "native single-head sibling"})
  git({"remote", "add", "origin", "https://github.com/acme/native-board.git"})
  git({"remote", "add", "other", "https://github.com/acme/other-board.git"})
  git({"config", "gitboard.remote", "origin"})
  local bad_config = command({"single-head", "configure", "--remote", "other",
      "--repository", "acme/native-board", "--branch", "envelope-poc"}, 1)
  assert(bad_config:find("not destination", 1, true), bad_config)
  assert(git({"config", "--get", "gitboard.remote"}) == "origin")
  local snapshot, serr = objects.snapshot(board, "refs/heads/")
  assert(snapshot ~= nil, serr)
  for ref, sha in pairs(snapshot) do
    local target = "refs/remotes/origin/" .. ref:sub(#"refs/heads/" + 1)
    assert(refs.update_ref(board, target, sha, refs.ZERO_SHA))
  end
  local tree, terr = objects.make_tree(board, {})
  assert(tree ~= nil, terr)
  local seed, seederr = objects.make_commit(board, tree, "native seed")
  assert(seed ~= nil, seederr)
  assert(refs.update_ref(board, "refs/remotes/origin/envelope-poc", seed,
      refs.ZERO_SHA))
  local configured = command({"single-head", "configure", "--remote", "origin",
      "--repository", "acme/native-board", "--branch", "envelope-poc"})
  assert(not configured:find("helper", 1, true), configured)
  -- The public CLI starts a fresh process for every command. This in-process
  -- harness must refresh refsconfig's per-process cache after configure.
  assert(refs.set_board_mode(board, "remote"))
  local refused = command({"refresh", "--remote", "other"}, 1)
  assert(refused:find("cannot change an active single%-head binding"), refused)
  local refresh_rebind = command({"single-head", "refresh", "--remote", "other"}, 1)
  assert(refresh_rebind:find("only accepted by single%-head configure"), refresh_rebind)
  assert(git({"config", "--get", "gitboard.remote"}) == "origin")
  local seed_plan = fs.join(tmp, "seed.literal")
  command({"single-head", "seed-plan", "--head", seed, "--out", seed_plan})
  local plan, perr = plans.load(seed_plan)
  assert(plan ~= nil, perr)
  local head, herr = plans.local_candidate(board, plan)
  assert(head ~= nil, herr)
  assert(refs.update_ref(board, "refs/remotes/origin/envelope-poc", head, seed))
  local refreshed = command({"single-head", "refresh"})
  assert(refreshed:find("refs/heads/envelope%-poc:refs/remotes/origin/envelope%-poc"),
    refreshed)
  assert(not refreshed:find("refs/heads/items/*", 1, true), refreshed)
  return head
end
bootstrap()

local function item_id(): string
  local snapshot = assert(objects.snapshot(board, "refs/remotes/origin/"))
  local ids: {string} = {}
  for ref in pairs(snapshot) do
    local id = ref:match("^refs/heads/items/(.+)$")
    if id ~= nil then ids[#ids + 1] = id end
  end
  table.sort(ids)
  return assert(ids[1])
end

local function test_draft_log_roundtrip()
  assert(command({"refresh"}, 1):find("REFUSED", 1, true))
  assert(command({"publish"}, 1):find("REFUSED", 1, true))
  local direct = command({"new", "must use a draft"}, 1)
  assert(direct:find("require a remote%-mode draft"), direct)
  assert(git({"for-each-ref", "--format=%(refname)",
        "refs/gitboard/prepared/"}) == "")
  command({"draft", "begin"})
  local draft = only_ref("refs/gitboard/drafts/")
  local note = fs.join(tmp, "note.md")
  assert(fs.write(note, "The exact log commit crosses the native envelope.\n"))
  local id = item_id()
  command({"log", id, "--add", note, "--draft", draft})
  local expected = command({"log", id, "--draft", draft})
  publish_local(draft, "draft")
  assert(command({"single-head", "refresh"}):find("confirmed draft", 1, true))
  assert(command({"log", id}) == expected)
end
test_draft_log_roundtrip()

local function product_repo(): string
  local product = fs.join(tmp, "product")
  assert(fs.make_dirs(product))
  git({"init", "-q"}, product)
  assert(fs.write(fs.join(product, "README"), "product\n"))
  git({"add", "README"}, product)
  git({"-c", "user.name=Test", "-c", "user.email=test@example.com",
      "commit", "-q", "-m", "base"}, product)
  return product
end

local function test_claim_lifecycle_and_historical_receipt()
  local id, session = item_id(), "0123456789abcdef0123456789abcdef"
  local product = product_repo()
  local take = command({"claim", id, "--session", session,
      "--repo-dir", product}, 2)
  assert(not take:find("git push %-%-atomic"), take)
  local take_ref = only_ref("refs/gitboard/prepared/")
  local take_sha = assert(refs.read_ref(board, take_ref))
  publish_local(take_ref, "take")
  assert(command({"single-head", "refresh"}):find("authority active", 1, true))
  command({"renew", id, "--session", session}, 2)
  local renew_ref = only_ref("refs/gitboard/prepared/")
  publish_local(renew_ref, "renew")
  assert(command({"single-head", "refresh"}):find("authority active", 1, true))
  command({"drop", id, "--session", session}, 2)
  local drop_ref = only_ref("refs/gitboard/prepared/")
  publish_local(drop_ref, "drop")
  assert(command({"single-head", "refresh"}):find(
      "no claim authority remains", 1, true))
  assert(refs.update_ref(board, take_ref, take_sha, refs.ZERO_SHA))
  local late = command({"single-head", "refresh"})
  assert(late:find("confirmed historical claim publication", 1, true), late)
  assert(not late:find("authority active", 1, true), late)
  assert(refs.read_ref(board, take_ref) == refs.ZERO_SHA,
    "historically confirmed staging receipt must be retired")
end
test_claim_lifecycle_and_historical_receipt()
print("gitsinglehead_cli_test: ok")
