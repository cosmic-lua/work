--- `brief`: emit the prompt a subagent runs one role from — builder,
--- research, review, refine, decompose — with every placeholder the board
--- can answer already filled: id, handle, title, spec sidecar verbatim,
--- repo/base/item branch, the exact product commit, this checkout's own
--- path. Templates are `_work.brieftext` and `_work.brieftext_review`;
--- `review` picks between full and mechanical exact-head reviews. The
--- fill grammar is `<UPPER_SNAKE>`, and a placeholder the board cannot
--- answer (a worktree path, a bounce paragraph) survives the fill — the
--- closing verdict line names each survivor, so the caller's whole job
--- is those and pasting the body verbatim.
---
--- Every brief also names the session its subject is already claimed
--- under (`it.claim`) on the closing verdict line — `gitboard session
--- new` is the only way a claim identity comes into existence, so no
--- brief kind mints one of its own.
---
--- Every body also carries `_work.brieftext_friction`'s `ASK` after
--- its own "Final report" section, unconditionally, instead of an
--- orchestrator appending it by hand.
---
--- A read, not a mutation: nothing here writes the board.
local briefcommands = require("_work.briefcommands")
local briefmeasure = require("_work.briefmeasure")
local brieftext = require("_work.brieftext")
local gitinvocation = require("_work.gitinvocation")
local receipt = require("_work.preparation_receipt")
local brieftext_friction = require("_work.brieftext_friction")
local brieftext_review = require("_work.brieftext_review")
local child = require("cosmic.child")
local claim = require("_work.claim")
local claimbatch = require("_work.claimbatch")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local gate = require("_work.gitgate")
local item = require("_work.item")
local repository_map = require("_work.repository_map")
local store = require("_work.store")
local tail = require("_work.tail")

local KINDS < const >: {string: string} = {
  builder = brieftext.BUILDER,
  research = brieftext.RESEARCH,
  review = brieftext_review.REVIEW,
  refine = brieftext.REFINE,
  decompose = brieftext.DECOMPOSE,
}

--- The kind names, alphabetical, for refusals and help.
local KIND_LIST < const > = "builder, decompose, refine, research, review"

--- Replace every `<UPPER_SNAKE>` placeholder that `values` answers;
--- one the map does not answer survives verbatim.
--- @param text string The template
--- @param values {string: string} Fill values by placeholder name
--- @return string The filled text
local function fill(text: string, values: {string: string}): string
  local out = text:gsub("<(%u[%u_]*)>", function(key: string): string | nil
      return values[key]
    end)
  return out
end

--- The `<UPPER_SNAKE>` placeholder-shaped tokens present in `text`,
--- first-seen order, each once. Used on a raw template (its declared
--- placeholders) and, in the test below, on an already-filled string.
--- @param text string The text to scan
--- @return {string} Placeholder names, possibly empty
local function unfilled(text: string): {string}
  local seen: {string: boolean} = {}
  local out: {string} = {}
  for key in text:gmatch("<(%u[%u_]*)>") do
    if not seen[key] then
      seen[key] = true
      out[#out + 1] = ("<%s>"):format(key)
    end
  end
  return out
end

--- The `template`'s OWN declared placeholders that `values` leaves
--- unanswered — checked by looking `values` up directly, never by
--- scanning the filled body. A spec quoting a placeholder-shaped token
--- verbatim (`<N>`, `<ID>`, `<REVIEW_SESSION>` as example syntax or
--- old-name prose) rides inside `values["SPEC"]`'s own text; since only
--- names the template itself declares are ever candidates, such a token
--- can never be mistaken for one the caller still owes a fill.
--- @param template string The raw, unfilled template
--- @param values {string: string} The fill values actually used
--- @return {string} Placeholder names still unanswered, first-seen order
local function survivors(template: string, values: {string: string}): {string}
  local out: {string} = {}
  for _, ph in ipairs(unfilled(template)) do
    local key = ph:sub(2, #ph - 1)
    if values[key] == nil then
      out[#out + 1] = ph
    end
  end
  return out
end

--- Whether a diff is small and mechanical enough to earn
--- `brieftext_review.REVIEW_SCRIPT`'s numbered script instead of
--- `REVIEW`'s full adversarial prompt: every changed `.tl` file is a
--- `*_test.tl` file, or the diff totals fewer than 20 changed lines.
--- @param files {string} The PR's changed file paths
--- @param additions integer The PR's added line count
--- @param deletions integer The PR's removed line count
--- @return boolean True when the numbered script applies
local function is_mechanical_diff(files: {string}, additions: integer,
    deletions: integer): boolean
  if additions + deletions < 20 then
    return true
  end
  for _, f in ipairs(files) do
    if f:match("%.tl$") ~= nil and f:match("_test%.tl$") == nil then
      return false
    end
  end
  return true
end

--- Inspect a handed-over change using only the caller-managed local
--- product checkout; a failed mapping merely selects the full review.
--- @param s store.Store The store
--- @param it item.Item The item under brief
--- @return boolean True when local Git proves the change is mechanical
local function local_mechanical_diff(s: store.Store, it: item.Item): boolean
  local base, head = it.claim_base or "", it.handover_head or ""
  if base == "" or head == "" then return false end
  local root, _rerr = repository_map.resolve(s.root, it.repo or "", "")
  if root == nil then return false end
  local r, _err = child.run({"git", "diff", "--numstat", "--no-renames",
      base, head, "--"}, {cwd = root})
  if r == nil or not r.ok then return false end
  local files: {string} = {}
  local additions, deletions = 0, 0
  for line in r.stdout:gmatch("([^\n]+)") do
    local a, d, path = line:match("^(%S+)\t(%S+)\t(.+)$")
    if a == nil or d == nil or path == nil then return false end
    files[#files + 1] = path
    local ai, di = math.tointeger(tonumber(a)), math.tointeger(tonumber(d))
    if ai == nil or di == nil then return false end
    additions, deletions = additions + ai, deletions + di
  end
  return is_mechanical_diff(files, additions, deletions)
end

--- Rework context contains only facts the board actually owns: the
--- verdict kind and commit id, never review prose reconstructed by gitboard.
local function bounce_context(it: item.Item, branch?: string): string
  if (it.verdict or "") ~= "request changes" then return "" end
  return fill(brieftext.REWORK, {
      JUDGED_HEAD = it.verdict_head or "",
      BRANCH = branch or it.id:sub(1, 8),
    })
end

--- `<PRODUCT_ROOT>`: the checkout holding `bin/gitboard`. The first
--- attempt is `GITBOARD_DIR`'s parent's parent, right and cheap for the
--- cold-start bootstrap that sets `GITBOARD_DIR` to `<root>/o/board`; it
--- is wrong for the sibling-reuse bootstrap (`GITBOARD_DIR` a sibling
--- clone's own root instead), verified by checking for `bin/gitboard`
--- rather than trusting the arithmetic. On failure, fall back to
--- searching upward from this process's own cwd for the nearest
--- ancestor holding `bin/gitboard`. "" when neither finds one.
--- @return string The product checkout's absolute path, "" if unknown
local function product_root(): string
  local dir = env.get("GITBOARD_DIR")
  if dir ~= nil and dir ~= "" then
    local guess = fs.absolute_path(fs.dirname(fs.dirname(dir)))
    if fs.is_file(fs.join(guess, "bin/gitboard")) then
      return guess
    end
  end
  local cur, _err = fs.cwd()
  while cur ~= nil do
    if fs.is_file(fs.join(cur, "bin/gitboard")) then
      return cur
    end
    local parent = fs.dirname(cur)
    if parent == cur then
      break
    end
    cur = parent
  end
  return ""
end

--- The checkout `worktree ID` makes for this item's claim: the same
--- `<checkout>/../wt/<branch>` path `_work.gitworktree` builds, from the
--- same repository map and claim batch. "" when the item has no claim
--- batch, its batch no longer holds a claim, or no local checkout is
--- mapped for its repo.
--- @param s store.Store The store
--- @param it item.Item The item under brief
--- @return string The worktree path, "" when it cannot be derived
local function worktree_path(s: store.Store, it: item.Item): string
  local pointer = it.claim_batch or ""
  if pointer == "" then return "" end
  local st, _serr = claimbatch.read_state(s.root, pointer, it.id)
  if st == nil then return "" end
  local checkout, _cerr = repository_map.resolve(s.root, it.repo or "", "")
  if checkout == nil then return "" end
  return claim.worktree(checkout, claim.branch(it.id, st.root))
end

--- brief: print one role's prompt for an item, filled from the board.
--- The body prints first and the verdict line closes it (the `show`
--- shape), naming the placeholders left for the caller. `out`, when
--- given, writes the filled body to that file instead of printing
--- it — a channel that decodes escapes (a pasted `\uXXXX`, `\t`, a
--- line-continuation backslash) corrupts a pasted prompt but cannot
--- touch a file — and the verdict line names the path in place of
--- the printed body.
--- @param s store.Store The store
--- @param kind string builder | research | review | refine | decompose
--- @param id string The item the brief is about
--- @param out string | nil Write the body here instead of stdout
--- @param gb_command string | nil `--gitboard-command`: caller's exact
--- invocation, prefixed onto every board command printed; requires
--- `gb_cwd`. Falls back to a builder `--receipt`'s own recorded
--- invocation when omitted; unresolved when neither is present
--- @param gb_cwd string | nil `--gitboard-cwd`: cwd for `gb_command`
--- @return integer Exit code
local function cmd_brief(s: store.Store, kind: string, id: string,
    out?: string, tree?: string, receipt_file?: string, caller?: string,
    gb_command?: string, gb_cwd?: string): integer
  out = out or ""
  tree = tree or ""
  gb_command = gb_command or ""
  gb_cwd = gb_cwd or ""
  local template = KINDS[kind or ""]
  if template == nil then
    return gate.verdict_line("brief", false,
      ("unknown brief '%s' — one of: %s"):format(tostring(kind), KIND_LIST))
  end
  if tree ~= "" and not fs.is_dir(tree) then
    return gate.verdict_line("brief", false,
      ("--tree '%s' must be a directory"):format(tree))
  end
  if (gb_command == "") ~= (gb_cwd == "") then
    return gate.verdict_line("brief", false,
      "--gitboard-command and --gitboard-cwd must be supplied together")
  end
  local it, lerr = store.load(s, id)
  if it == nil then
    return gate.verdict_line("brief", false, lerr)
  end
  if receipt_file == "" then return gate.verdict_line("brief", false, "empty --receipt") end
  if caller ~= nil and receipt_file == nil then
    return gate.verdict_line("brief", false, "--session requires a builder --receipt")
  end
  local prep, perr = receipt.read(s, it, kind, receipt_file or "", caller or "", tree)
  if perr ~= "" then return gate.verdict_line("brief", false, perr) end
  -- The caller's own flags win outright; a builder with no direct flags
  -- falls back to its --receipt's own recorded invocation. Neither
  -- present leaves it unresolved — never a guessed `bin/gitboard`.
  local gitboard_command, gitboard_cwd = gb_command, gb_cwd
  if gitboard_command == "" and kind == "builder" then
    gitboard_command = prep["gitboard-command"] or ""
    gitboard_cwd = prep["gitboard-cwd"] or ""
  end
  local spec = store.read_spec(s, id)
  if spec == "" and kind ~= "decompose" then
    return gate.verdict_line("brief", false,
      ("%s has no spec sidecar — a %s brief carries the spec verbatim, "
        .. "so refine it first"):format(id:sub(1, 8), kind))
  end
  -- Every review judges an exact product handover, including research.
  -- Legacy result metadata cannot substitute for or override that commit.
  local head_sha = ""
  if kind == "review" then
    if (it.handover_head or "") == "" then
      if (it.result or "") ~= "" then
        return gate.verdict_line("brief", false,
          ("%s has a legacy research result but no commit handover — the caller must "
            .. "supply the applying product commit with `take %s --head SHA`")
          :format(id:sub(1, 8), id:sub(1, 8)))
      end
      return gate.verdict_line("brief", false,
        ("%s has no handover recorded — `take %s --head SHA` is what "
          .. "a commit review judges"):format(id:sub(1, 8), id:sub(1, 8)))
    else
      head_sha = it.handover_head or ""
      if local_mechanical_diff(s, it) then
        template = brieftext_review.REVIEW_SCRIPT
      end
    end
    -- A review names a live claim `verdict` will accept — never mints one.
    if (it.claim or "") == "" then
      return gate.verdict_line("brief", false,
        ("%s carries no active claim — a review records its verdict under "
          .. "the claim it is spawned from; claim it with a session from "
          .. "`gitboard session new`, then re-run this brief"):format(id:sub(1, 8)))
    end
    local distance = gate.distance_refusal(it, it.claim)
    if distance ~= nil then
      return gate.verdict_line("brief", false,
        ("%s is still claimed by the session that built it — %s"):format(
          id:sub(1, 8), distance))
    end
  end
  local label = prep.session or it.claim or ""
  local values: {string: string} = {
    PREPARATION = prep.session ~= nil and receipt.context(prep) or brieftext.BUILDER_PREPARATION,
    ITEM_ID = it.id,
    HANDLE = tail.handle(it.id),
    TITLE = it.title,
    BRANCH = prep.branch or it.id:sub(1, 8),
    WORKTREE = prep.worktree,
    SPEC = spec,
    CURRENT_SPEC = spec ~= "" and spec or "(the item has no spec sidecar)",
    BOARD_DIR = fs.absolute_path(s.root),
    REVIEW_SESSION = label,
    ROUND_CONTEXT = "",
    CLAIM_BASE = prep["product-base"] or it.claim_base or "",
    CHANGE_SOURCE = (it.external_url or "") ~= ""
    and (("Commit: `%s`\nExternal link (navigation only): %s")
      :format(head_sha, it.external_url or ""))
    or (("Commit: `%s`"):format(head_sha)),
    GITBOARD_CMD = gitinvocation.prefix(gitboard_command, gitboard_cwd),
  }
  local root = prep.session == nil and product_root() or ""
  if root ~= "" then
    values["PRODUCT_ROOT"] = root
  end
  -- `<WORKTREE>`: fills once `worktree ID` (or `--review`) has made the
  -- checkout on disk — unfilled until then, like any other placeholder
  -- the board cannot yet answer. `REVIEW_SCRIPT` carries no `<WORKTREE>`.
  if kind == "builder" or (kind == "review"
    and template:find("<WORKTREE>", 1, true) ~= nil) then
    local wt = worktree_path(s, it)
    if wt ~= "" and fs.is_dir(wt) then
      values["WORKTREE"] = wt
    end
  end
  if kind == "builder" then
    local bc = bounce_context(it, prep.branch)
    if bc ~= "" then
      values["BOUNCE_CONTEXT"] = bc
    end
  end
  local repo = it.repo or ""
  if repo ~= "" then
    values["REPO"] = repo
    if (it.base or "") ~= "" then
      values["BASE_BRANCH"] = it.base
    elseif repo:find("cosmopolitan", 1, true) ~= nil then
      values["BASE_BRANCH"] = "master"
    else
      values["BASE_BRANCH"] = "main"
    end
  elseif (it.base or "") ~= "" then
    values["BASE_BRANCH"] = it.base
  end
  if head_sha ~= "" then
    values["HEAD_SHA"] = head_sha
  end
  if kind == "builder" or kind == "review" then
    local checkout, _cerr = repository_map.resolve(s.root, it.repo or "", "")
    for key, value in pairs(briefcommands.commands(checkout or "", kind)) do
      values[key] = value
    end
  end
  local body = fill(template, values)
  local measured = false
  if tree ~= "" and (kind == "builder" or kind == "review") then
    local section, merr = briefmeasure.measure(spec, tree)
    if section == nil then
      return gate.verdict_line("brief", false,
        ("could not measure --tree '%s': %s"):format(tree, merr))
    end
    body = body .. "\n\n" .. section
    measured = true
  end
  body = body .. "\n\n" .. brieftext_friction.ASK
  local left = survivors(template, values)
  -- An unclaimed item's brief (builder, research, refine, decompose) has
  -- no session to name, so it carries no clause and no minted stand-in.
  local session_phrase = prep.session ~= nil and "prepared session" or "claimed under session"
  local session_clause = label ~= "" and (", %s %s"):format(session_phrase, label) or ""
  local mint_note = "mint a session with `gitboard session new` and claim it before spawning — "
  if out ~= "" then
    local wok, werr = fs.write(out, body)
    if not wok then
      return gate.verdict_line("brief", false,
        ("could not write %s: %s"):format(out, werr))
    end
    local tail_note = "nothing left to fill — read it whole, it is your brief verbatim"
    if #left > 0 then
      tail_note = ("fill %s, then read it whole, it is your brief verbatim"):format(
        table.concat(left, ", "))
    end
    if measured then
      tail_note = tail_note .. ("; measured Change paths under %s"):format(tree)
    end
    tail_note = label == "" and (mint_note .. tail_note) or tail_note
    return gate.verdict_line("brief",
      true, ("%s brief for %s written to %s%s — %s"):format(
        kind, tail.handle(it.id), out, session_clause, tail_note))
  end
  print(body)
  local tail_note = "nothing left to fill — paste the body verbatim"
  if #left > 0 then
    tail_note = ("fill %s, then paste the body verbatim"):format(
      table.concat(left, ", "))
  end
  if measured then
    tail_note = tail_note .. ("; measured Change paths under %s"):format(tree)
  end
  tail_note = label == "" and (mint_note .. tail_note) or tail_note
  return gate.verdict_line("brief",
    true, ("%s brief for %s%s — %s"):format(
      kind, tail.handle(it.id), session_clause, tail_note))
end

local record brief
  fill: function(text: string, values: {string: string}): string
  unfilled: function(text: string): {string}
  cmd_brief: function(s: store.Store, kind: string, id: string, out?: string,
  tree?: string, receipt_file?: string, caller?: string,
  gb_command?: string, gb_cwd?: string): integer
end

local M: brief = {
  fill = fill,
  unfilled = unfilled,
  cmd_brief = cmd_brief,
}

return M
