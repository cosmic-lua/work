--- init: prepare a state repository, and record which namespace its
--- board refs live in. Split out of `_work.gitboard`, which sits
--- against the file cap; this is the one verb there that runs before a
--- store is open at all, so it reads its own flags and touches
--- nothing else the dispatcher holds.
---
--- Mode and remote are recorded BEFORE initialization reads any board
--- ref, because an existing clone must select its namespace first: a
--- read against the wrong namespace would answer from refs this board
--- does not own. A brand-new directory has no repository config to
--- write into yet, so it is initialized first and marked immediately
--- afterwards — the same two settings, in the only order each case
--- allows.
local fs = require("cosmic.fs")
local gate = require("_work.gitgate")
local refs = require("_work.refs")
local store = require("_work.store")

--- Record the board's ref namespace in the checkout's Git config.
--- @param dir string The checkout
--- @param remote boolean --remote: caller-fetched tracking refs are canonical
--- @return boolean True when it landed
--- @return string Error message
local function set_mode(dir: string, remote: boolean): boolean, string
  if remote then
    return refs.set_board_mode(dir, "remote")
  end
  return refs.set_board_mode(dir, "local")
end

--- @param dir string The state repository checkout
--- @param remote boolean --remote: use caller-fetched remote-tracking refs
--- @param local_mode boolean --local: use local heads (tests, migrations)
--- @param remote_name string --remote-name's value, "" when unset
--- @return integer Exit code
local function cmd_init(dir: string, remote: boolean, local_mode: boolean,
    remote_name: string): integer
  if remote and local_mode then
    return gate.verdict_line("init", false,
      "REFUSED: choose at most one of --remote and --local")
  end
  if local_mode and remote_name ~= "" then
    return gate.verdict_line("init", false,
      "REFUSED: --remote-name belongs to a remote-backed board")
  end
  local existing = fs.is_dir(fs.join(dir, ".git"))
  local mode_set = false
  local remote_set = false
  if existing and remote_name ~= "" then
    local configured, cerr = refs.set_board_remote(dir, remote_name)
    if not configured then return gate.verdict_line("init", false, cerr) end
    remote_set = true
  end
  if existing and (remote or local_mode) then
    local configured, cerr = set_mode(dir, remote)
    if not configured then return gate.verdict_line("init", false, cerr) end
    mode_set = true
  end
  local ok, err = store.init_repo(dir)
  if not ok then
    return gate.verdict_line("init", false, err)
  end
  if not mode_set and (remote or local_mode) then
    local configured, cerr = set_mode(dir, remote)
    if not configured then return gate.verdict_line("init", false, cerr) end
  end
  if remote_name ~= "" and not remote_set then
    local configured, cerr = refs.set_board_remote(dir, remote_name)
    if not configured then return gate.verdict_line("init", false, cerr) end
  end
  if remote_name ~= "" then
    local remote_mode, merr = refs.set_board_mode(dir, "remote")
    if not remote_mode then return gate.verdict_line("init", false, merr) end
  end
  return gate.verdict_line("init", true,
    ("state repository ready at %s (%s%s)"):format(dir, refs.board_mode(dir),
      refs.board_mode(dir) == "remote" and ", " .. refs.board_remote(dir) or ""))
end

local record gitinit
  cmd_init: function(dir: string, remote: boolean, local_mode: boolean,
  remote_name: string): integer
end

local M: gitinit = {
  cmd_init = cmd_init,
}

return M
