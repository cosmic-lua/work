#!/usr/bin/env cosmic
--- Work board CLI over Git-backed item refs. Roles emerge from the graph;
--- durable workflow facts are commit IDs, and authenticated remote actions
--- belong to the caller. Commands prepare and print exact Git instructions by
--- default; `--execute` runs only those ordinary Git commands. The command
--- table and help text live in `_work.gitcommands`.
local flags = require("cosmic.flags")
local fs = require("cosmic.fs")
local proc = require("cosmic.proc")
local brief = require("_work.brief")
local cachequery = require("_work.cachequery")
local commands = require("_work.gitcommands")
local doctrine = require("_work.doctrine")
local fsck = require("_work.gitfsck")
local gate = require("_work.gitgate")
local claimcli = require("_work.gitclaim_cli")
local gitread = require("_work.gitread")
local gitdone = require("_work.gitdone")
local draftcli = require("_work.gitdraft_cli")
local graph = require("_work.gitgraph")
local gitspec = require("_work.gitspec")
local transport = require("_work.gittransport")
local gittake = require("_work.gittake")
local gitworktree = require("_work.gitworktree")
local publish = require("_work.publish")
local rank = require("_work.gitrank")
local refs = require("_work.refs")
local session = require("_work.session")
local store = require("_work.store")
local tail = require("_work.tail")
local vrd = require("_work.gitverdict")
local show = require("_work.gitshow")
local view = require("_work.gitview")

--- Commands that may still use the board sequence for global ordering.
--- as `LOST_RACE` by the push itself (`_work.publish.publish`, which
--- re-syncs on rejection), costing a round trip only when a race
--- actually happened. `sync` and lane minting fetch on their own,
--- outside this dispatch.
local FETCH_FIRST: {string: boolean} = {}

--- Resolve one id-taking argument, whatever position it sits in: an
--- id prefix is tried first; only when that refuses AND the input has
--- a tail's shape (8 base62 characters, one optional hyphen, either
--- bare or guillemet-wrapped) does tail resolution follow — so a
--- plain id-prefix typo still gets store.resolve's own message. A
--- tail costs no whole-board load: the cache answers first, with no
--- process at all, when `o/board.db` already carries the id
--- (`_work.cachequery.resolve_tail`); a miss there — the cache file is
--- absent, or the item is newer than it — falls to
--- `_work.tail.resolve_glob`'s own `for-each-ref` glob. Every
--- id-taking argument (the first, and PARENT/OTHER/BLOCKER) routes
--- through this so a rendered handle resolves in any position.
--- @param s store.Store The store
--- @param input string What a session typed
--- @return string | nil The resolved item id
--- @return string Error message
local function resolve_id(s: store.Store, input: string): string | nil, string
  local id, rerr = store.resolve(s, input)
  if id ~= nil or not tail.is_tail_shape(input) then
    return id, rerr
  end
  local cached, cerr = cachequery.resolve_tail(s.root, input)
  if cerr ~= "" then
    return nil, cerr
  end
  if cached ~= nil then
    return cached, ""
  end
  local resolved, gerr = tail.resolve_glob(s.root, input)
  if resolved == nil then
    return nil, gerr
  end
  -- The one-shot ticket `resolve`'s own prefix match sets, so a
  -- handle costs `load` no for-each-ref of its own either.
  if resolved.ref ~= "" and resolved.sha ~= "" then
    s.fresh_lease = gitread.lease_encode(resolved.id, resolved.ref, resolved.sha)
  end
  return resolved.id, ""
end

local CSPEC: flags.CommandSpec = commands.CSPEC

--- Resolve --before/--after into full ids, "" for a flag not given —
--- shared by `new`, `attach`, and `rank`, whose X arguments all name
--- an existing sibling the same way every other id-taking argument
--- does.
--- @param s store.Store The store
--- @param values {string: string} `d.parsed.values`
--- @return string before, full id or ""
--- @return string after, full id or ""
--- @return string err "" on success
local function resolve_before_after(s: store.Store, values: {string: string}):
  string, string, string
  local function resolve_one(key: string): string, string
    local v = values[key]
    if v == nil then
      return "", ""
    end
    local resolved, rerr = resolve_id(s, v)
    if resolved == nil then
      return "", rerr
    end
    return resolved, ""
  end
  local before, berr = resolve_one("before")
  if berr ~= "" then
    return "", "", berr
  end
  local after, aerr = resolve_one("after")
  if aerr ~= "" then
    return "", "", aerr
  end
  return before, after, ""
end

--- CLI entry point.
--- @param ... string Command-line arguments
--- @return integer Exit code
local function main(...: string): integer
  -- `help <topic>` serves doctrine before the dispatcher sees it: a
  -- topic is not a command, and never shadows a verb (doctrine_test).
  local argv = {...}
  if argv[1] == "help" and argv[2] ~= nil then
    local topic = doctrine.page(argv[2])
    if topic ~= nil then
      print(topic)
      return 0
    end
  end
  local d, derr = flags.command(CSPEC, argv)
  if d == nil then
    io.stderr:write(tostring(derr) .. "\n")
    io.stderr:write(flags.command_help(CSPEC)
      .. "\n\n" .. doctrine.listing() .. "\n")
    return 1
  end
  if d.help or d.command == nil then
    local text = flags.command_help(CSPEC, d.command)
    if d.command == nil then
      text = text .. "\n\n" .. doctrine.listing()
    end
    print(text)
    return 0
  end
  if d.command == "session" then
    return claimcli.cmd_session(d.parsed.args[1] or "")
  end
  if d.command == "init" then
    local dir = d.parsed.values["dir"] or "."
    local remote_name = d.parsed.values["remote-name"] or ""
    if d.parsed.switches["remote"] and d.parsed.switches["local"] then
      return gate.verdict_line("init", false,
        "REFUSED: choose at most one of --remote and --local")
    end
    if d.parsed.switches["local"] and remote_name ~= "" then
      return gate.verdict_line("init", false,
        "REFUSED: --remote-name belongs to a remote-backed board")
    end
    -- Existing clones must select their namespace before initialization reads
    -- any board ref. A brand-new directory has no repository config yet, so it
    -- is initialized first and marked immediately afterward.
    local mode_set = false
    local remote_set = false
    if fs.is_dir(fs.join(dir, ".git")) and remote_name ~= "" then
      local configured, cerr = refs.set_board_remote(dir, remote_name)
      if not configured then return gate.verdict_line("init", false, cerr) end
      remote_set = true
    end
    if fs.is_dir(fs.join(dir, ".git"))
    and (d.parsed.switches["remote"] or d.parsed.switches["local"]) then
      local configured, cerr: boolean, string
      if d.parsed.switches["remote"] then
        configured, cerr = refs.set_board_mode(dir, "remote")
      else
        configured, cerr = refs.set_board_mode(dir, "local")
      end
      if not configured then return gate.verdict_line("init", false, cerr) end
      mode_set = true
    end
    local ok, err = store.init_repo(dir)
    if not ok then
      return gate.verdict_line("init", false, err)
    end
    if not mode_set
    and (d.parsed.switches["remote"] or d.parsed.switches["local"]) then
      local configured, cerr: boolean, string
      if d.parsed.switches["remote"] then
        configured, cerr = refs.set_board_mode(dir, "remote")
      else
        configured, cerr = refs.set_board_mode(dir, "local")
      end
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
  local dir = d.parsed.values["dir"] or "."
  local explicit_remote = d.parsed.values["remote"] or ""
  if explicit_remote ~= "" then
    local selected, selerr = refs.use_remote(dir, explicit_remote)
    if not selected then return gate.verdict_line(d.command or "gitboard", false,
        selerr) end
  end
  local remote = explicit_remote ~= "" and explicit_remote or refs.board_remote(dir)
  if d.command == "draft" then
    return draftcli.cmd_draft(dir, d.parsed.args,
      d.parsed.switches["print-id"] or false)
  end
  local selected_draft, draft_err = draftcli.activate(dir, d.command,
    d.parsed.values["draft"])
  if selected_draft == nil then
    return gate.verdict_line(d.command, false, "REFUSED: " .. draft_err)
  end
  local s, serr = store.open(dir)
  if s == nil then
    io.stderr:write(tostring(serr) .. "\n")
    return 1
  end
  if FETCH_FIRST[d.command] then
    local synced, syerr = publish.sync(s)
    if not synced then
      io.stderr:write(("gitboard-%s: could not sync before mutating: %s\n")
        :format(d.command, syerr))
      return 1
    end
  end
  if d.command == "next" then
    local who = session.resolve(d.parsed.values["session"])
    return view.cmd_next(s, who)
  end
  if d.command == "sync" then
    io.stderr:write("gitboard-sync: deprecated; use `gitboard refresh`\n")
    return transport.cmd_refresh(s, remote, false)
  end
  if d.command == "publish" then
    local selectors = d.parsed.args
    if #selectors == 0 and selected_draft ~= "" then selectors = {selected_draft} end
    return transport.cmd_publish(s, selectors,
      remote,
      d.parsed.switches["execute"] or false)
  end
  if d.command == "refresh" then
    return transport.cmd_refresh(s, remote,
      d.parsed.switches["execute"] or false)
  end
  if d.command == "claim" or d.command == "renew" or d.command == "drop" then
    local ids: {string} = {}
    for _, input_id in ipairs(d.parsed.args) do
      local resolved, rerr = resolve_id(s, input_id)
      if resolved == nil then
        io.stderr:write(tostring(rerr) .. "\n")
        return 1
      end
      ids[#ids + 1] = resolved
    end
    return claimcli.cmd_claim(s, ids,
      d.command == "renew" and "renew"
      or d.command == "drop" and "drop" or "take",
      d.parsed.values["session"] or "",
      remote,
      d.parsed.values["repo-dir"] or "",
      d.parsed.switches["force"] or false,
      d.parsed.values["why"] or "",
      d.parsed.switches["execute"] or false)
  end
  if d.command == "fsck" then
    return fsck.cmd_fsck(s)
  end
  if d.command == "find" then
    return cachequery.cmd_find(s.root, table.concat(d.parsed.args, " "))
  end
  -- Bare `show` is the board; `show ID` is one item, resolved below
  -- with every other id-taking verb — `--todo` has no effect there.
  if d.command == "show" and (d.parsed.args[1] or "") == "" then
    local raw = d.parsed.values["todo"]
    if raw == nil then
      return view.cmd_status(s)
    end
    local todo_shown = math.tointeger(tonumber(raw))
    if todo_shown == nil or todo_shown < 0 then
      return gate.verdict_line("show", false,
        ("--todo wants a non-negative integer, got %q"):format(raw))
    end
    return view.cmd_status(s, todo_shown)
  end
  -- `brief`'s first argument is the KIND, not an id, so it cannot
  -- ride the shared id resolution below. A missing id passes through
  -- as "" so an unknown kind refuses on the kind, not on the id.
  if d.command == "brief" then
    local target = d.parsed.args[2] or ""
    if target ~= "" then
      local resolved, berr = resolve_id(s, target)
      if resolved == nil then
        io.stderr:write(tostring(berr) .. "\n")
        return 1
      end
      target = resolved
    end
    return brief.cmd_brief(s, d.parsed.args[1] or "", target,
      d.parsed.values["out"], d.parsed.values["tree"])
  end
  if d.command == "new" then
    local title = d.parsed.args[1]
    if title == nil or title == "" then
      io.stderr:write("new needs a title\n")
      return 1
    end
    local parent = ""
    local parent_prefix = d.parsed.values["parent"]
    if parent_prefix ~= nil then
      local resolved, perr = resolve_id(s, parent_prefix)
      if resolved == nil then
        io.stderr:write(tostring(perr) .. "\n")
        return 1
      end
      parent = resolved
    end
    local before, after, baerr = resolve_before_after(s, d.parsed.values)
    if baerr ~= "" then
      io.stderr:write(baerr .. "\n")
      return 1
    end
    local spec: string = nil
    local spec_file = d.parsed.values["spec-file"]
    if spec_file ~= nil then
      local body, rerr = fs.read(spec_file)
      if body == nil then
        io.stderr:write(tostring(rerr) .. "\n")
        return 1
      end
      spec = body
    end
    local who, werr = claimcli.resolve_optional_caller(
      d.parsed.values["session"] or "")
    if who == nil then return gate.verdict_line("new", false, "REFUSED: " .. werr) end
    return graph.cmd_new(s, title, parent, spec, d.parsed.values["repo"] or "",
      d.parsed.switches["force"], d.parsed.values["why"] or "", before, after,
      who)
  end
  local input = d.parsed.args[1] or ""
  local id, rerr = resolve_id(s, input)
  if id == nil then
    io.stderr:write(tostring(rerr) .. "\n")
    return 1
  end
  if d.command == "attach" then
    local parent, perr = resolve_id(s, d.parsed.args[2] or "")
    if parent == nil then
      io.stderr:write(tostring(perr) .. "\n")
      return 1
    end
    local before, after, baerr = resolve_before_after(s, d.parsed.values)
    if baerr ~= "" then
      io.stderr:write(baerr .. "\n")
      return 1
    end
    local who, werr = claimcli.resolve_optional_caller(
      d.parsed.values["session"] or "")
    if who == nil then
      return gate.verdict_line("attach", false, "REFUSED: " .. werr)
    end
    return graph.cmd_attach(s, id, parent, before, after, who,
      d.parsed.switches["force"], d.parsed.values["why"] or "")
  end
  if d.command == "rank" then
    local before, after, baerr = resolve_before_after(s, d.parsed.values)
    if baerr ~= "" then
      io.stderr:write(baerr .. "\n")
      return 1
    end
    local who, werr = claimcli.resolve_optional_caller(
      d.parsed.values["session"] or "")
    if who == nil then return gate.verdict_line("rank", false, "REFUSED: " .. werr) end
    return rank.cmd_rank(s, id, before, after,
      d.parsed.switches["last"] or false, who,
      d.parsed.switches["force"], d.parsed.values["why"] or "")
  end
  if d.command == "set" then
    local who, werr = claimcli.resolve_optional_caller(
      d.parsed.values["session"] or "")
    if who == nil then return gate.verdict_line("set", false, "REFUSED: " .. werr) end
    return graph.cmd_set(s, id, d.parsed.values["title"],
      d.parsed.values["repo"], d.parsed.values["base"], who,
      d.parsed.switches["force"], d.parsed.values["why"] or "")
  end
  if d.command == "spec" then
    local file = d.parsed.args[2]
    if file == nil then
      io.stderr:write("spec needs a markdown file\n")
      return 1
    end
    local who, werr = claimcli.resolve_optional_caller(
      d.parsed.values["session"] or "")
    if who == nil then return gate.verdict_line("spec", false, "REFUSED: " .. werr) end
    return gitspec.cmd_spec(s, id, file, d.parsed.values["base"] or "", who,
      d.parsed.switches["force"], d.parsed.values["why"] or "")
  end
  if d.command == "worktree" then
    local who = session.resolve(d.parsed.values["session"])
    return gitworktree.cmd_worktree(s, id, who, d.parsed.values["root"] or "",
      d.parsed.lists["ref"] or {}, d.parsed.switches["review"] or false,
      d.parsed.switches["verbose"] or false)
  end
  if d.command == "take" then
    local who, werr = claimcli.resolve_caller(d.parsed.values["session"] or "")
    if who == nil then
      return gate.verdict_line("take", false, "REFUSED: " .. werr)
    end
    local it, ierr = store.load(s, id)
    if it == nil then return gate.verdict_line("take", false, ierr) end
    return gittake.take_handover(s, it, who, d.parsed.values["head"] or "",
      d.parsed.values["url"] or "", d.parsed.values["repo-dir"] or "")
  end
  if d.command == "verdict" then
    local kind = d.parsed.args[2]
    if kind == nil then
      io.stderr:write("verdict needs a kind: accept, request changes, reject\n")
      return 1
    end
    local who, werr = claimcli.resolve_caller(d.parsed.values["session"] or "")
    if who == nil then
      return gate.verdict_line("verdict", false, "REFUSED: " .. werr)
    end
    return vrd.cmd_verdict_commit(s, id, kind,
      d.parsed.values["head"] or "", who,
      d.parsed.switches["force"], d.parsed.values["why"] or "",
      d.parsed.values["repo-dir"] or "")
  end
  if d.command == "done" then
    local by = ""
    local by_raw = d.parsed.values["by"]
    if by_raw ~= nil then
      local resolved, byerr = resolve_id(s, by_raw)
      if resolved == nil then
        io.stderr:write(tostring(byerr) .. "\n")
        return 1
      end
      by = resolved
    end
    local who, werr = claimcli.resolve_caller(d.parsed.values["session"] or "")
    if who == nil then
      return gate.verdict_line("done", false, "REFUSED: " .. werr)
    end
    return gitdone.cmd_done(s, id, d.parsed.values["reason"] or "completed",
      d.parsed.switches["force"], d.parsed.values["why"] or "", by,
      d.parsed.values["landed"] or "", d.parsed.values["repo-dir"] or "", who)
  end
  return show.cmd_show(s, id)
end

if proc.is_main() then
  os.exit(main(...))
end

local record gitboard
  main: function(...: string): integer
end

local M: gitboard = {
  main = main,
}

return M
