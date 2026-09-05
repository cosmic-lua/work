#!/usr/bin/env cosmic
--- Work board CLI over a state REPOSITORY, where roles emerge from the graph.
--- There are no kinds and no goal tier — the parentless item is the
--- board, its children are the outcomes, an item with open children
--- is a container being decomposed, and a childless item below the
--- outcome level is workable: the only thing that crosses the kanban.
--- Order is a path from the board — `gitboard help order` — derived by
--- `_work.rank`, never a number an item asserts about itself. Each
--- item is a git ref,
--- `refs/heads/items/<ksuid>` (`refs/heads/ended/<ksuid>` for one filed
--- before resolving stopped moving the ref), whose tip commit's tree
--- carries its fields and spec prose (`_work.store`);
--- the flow rules are `_work.flow`. Pull requests
--- stay on GitHub and carry the fix; issues shrink to an inbound
--- queue. Ids are KSUIDs; renders lead with the handle, the id's last
--- 8 characters (e.g. «d0x1_37YJ»); every verb accepts that handle,
--- bare or wrapped, either divider, case-tolerant — or an unambiguous prefix.
---
---   cosmic --make run _work/gitboard.tl init [--dir D]
---   cosmic --make run _work/gitboard.tl new "an outcome"
---   cosmic --make run _work/gitboard.tl new "a piece of it" --parent 2ai3
---   cosmic --make run _work/gitboard.tl attach 2akQ 2ai3
---   cosmic --make run _work/gitboard.tl rank 2akQ --before 2ai3 | --after 2ai3 | --last
---   cosmic --make run _work/gitboard.tl set 2akQ --title "a truer title"
---   cosmic --make run _work/gitboard.tl spec 2akQ SPEC.md
---   cosmic --make run _work/gitboard.tl show [2akQ]
---   cosmic --make run _work/gitboard.tl next [--session S]
---   cosmic --make run _work/gitboard.tl take 2akQ [--pr 42 | --result]
---   cosmic --make run _work/gitboard.tl drop 2akQ --why "wave agent died"
---   cosmic --make run _work/gitboard.tl verdict 2akQ accept [--pr N]
---   cosmic --make run _work/gitboard.tl done 2akQ [--reason not-planned]
---   cosmic --make run _work/gitboard.tl brief builder 2akQ
---   cosmic --make run _work/gitboard.tl sync
---   cosmic --make run _work/gitboard.tl help system
---
--- `help <topic>` serves the doctrine pages (`_work.doctrine`) — the
--- system of work itself, not one verb's options — and the overview
--- help lists the topics.
---
--- This file is the argument parsing, prefix resolution, and dispatch
--- half; the verbs themselves are `_work.gitverbs` (the state
--- verbs), `_work.gitgraph` (the graph mutations), and `_work.gitrank`
--- (`rank`, and the placement `attach`/`new` share with it). The
--- command table itself — every verb's usage, summary, and flags —
--- is `_work.gitcommands`, split out to keep this file under its line
--- cap; `help` and `help <verb>` are generated straight from it.
local flags = require("cosmic.flags")
local fs = require("cosmic.fs")
local proc = require("cosmic.proc")
local brief = require("_work.brief")
local cachequery = require("_work.cachequery")
local commands = require("_work.gitcommands")
local doctrine = require("_work.doctrine")
local fsck = require("_work.gitfsck")
local gate = require("_work.gitgate")
local gitread = require("_work.gitread")
local graph = require("_work.gitgraph")
local migrate = require("_work.gitmigrate")
local gitspec = require("_work.gitspec")
local gitsync = require("_work.gitsync")
local publish = require("_work.publish")
local rank = require("_work.gitrank")
local session = require("_work.session")
local store = require("_work.store")
local tail = require("_work.tail")
local verbs = require("_work.gitverbs")
local vrd = require("_work.gitverdict")
local show = require("_work.gitshow")
local view = require("_work.gitview")

--- The verbs whose save may be BOUNDED — advancing and leasing
--- `refs/heads/board/seq` (`_work.store.set_bounded`), so two of them racing
--- each other need to see the SAME seq tip: `take` (a NEW claim, the
--- doing bound). Only this fetches the remote's state before
--- mutating; every other write verb builds against this checkout's
--- own local refs and pushes straight away — a stale lease is refused
--- as `LOST_RACE` by the push itself (`_work.publish.publish`, which
--- re-syncs on rejection), costing a round trip only when a race
--- actually happened. `sync` and lane minting fetch on their own,
--- outside this dispatch.
local FETCH_FIRST: {string: boolean} = {
  ["take"] = true,
}

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
  if d.command == "init" then
    local dir = d.parsed.values["dir"] or "."
    local ok, err = store.init_repo(dir)
    if not ok then
      return gate.verdict_line("init", false, err)
    end
    return gate.verdict_line("init", true, ("state repository ready at %s"):format(dir))
  end
  local s, serr = store.open(d.parsed.values["dir"] or ".")
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
    return gitsync.cmd_sync(s)
  end
  if d.command == "fsck" then
    return fsck.cmd_fsck(s)
  end
  if d.command == "find" then
    return cachequery.cmd_find(s.root, table.concat(d.parsed.args, " "))
  end
  if d.command == "migrate" then
    return migrate.cmd_migrate(s, d.parsed.switches["dry-run"] or false)
  end
  -- Bare `show` is the board; `show ID` is one item, resolved below
  -- with every other id-taking verb.
  if d.command == "show" and (d.parsed.args[1] or "") == "" then
    return view.cmd_status(s)
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
    return brief.cmd_brief(s, d.parsed.args[1] or "", target)
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
    return graph.cmd_new(s, title, parent, spec, d.parsed.values["repo"] or "",
      d.parsed.switches["force"], d.parsed.values["why"] or "", before, after)
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
    return graph.cmd_attach(s, id, parent, before, after)
  end
  if d.command == "rank" then
    local before, after, baerr = resolve_before_after(s, d.parsed.values)
    if baerr ~= "" then
      io.stderr:write(baerr .. "\n")
      return 1
    end
    return rank.cmd_rank(s, id, before, after, d.parsed.switches["last"] or false)
  end
  if d.command == "set" then
    return graph.cmd_set(s, id, d.parsed.values["title"],
      d.parsed.values["repo"], d.parsed.values["base"])
  end
  if d.command == "spec" then
    local file = d.parsed.args[2]
    if file == nil then
      io.stderr:write("spec needs a markdown file\n")
      return 1
    end
    local who = session.resolve(d.parsed.values["session"])
    return gitspec.cmd_spec(s, id, file, d.parsed.values["base"] or "", who,
      d.parsed.switches["force"], d.parsed.values["why"] or "")
  end
  if d.command == "take" then
    local pr = math.tointeger(tonumber(d.parsed.values["pr"] or "0")) or 0
    local who = session.resolve(d.parsed.values["session"])
    return verbs.cmd_take(s, id, who, pr,
      d.parsed.switches["force"], d.parsed.values["why"] or "",
      d.parsed.switches["result"])
  end
  if d.command == "drop" then
    local who = session.resolve(d.parsed.values["session"])
    return verbs.cmd_drop(s, id, who, d.parsed.values["why"] or "",
      d.parsed.switches["force"])
  end
  if d.command == "verdict" then
    local kind = d.parsed.args[2]
    if kind == nil then
      io.stderr:write("verdict needs a kind: accept, request changes, reject\n")
      return 1
    end
    local pr = math.tointeger(tonumber(d.parsed.values["pr"] or "0")) or 0
    local who = session.resolve(d.parsed.values["session"])
    return vrd.cmd_verdict(s, id, kind, pr, d.parsed.values["head"] or "", who,
      d.parsed.switches["force"], d.parsed.values["why"] or "")
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
    return verbs.cmd_done(s, id, d.parsed.values["reason"] or "completed",
      d.parsed.switches["force"], d.parsed.values["why"] or "", by)
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
