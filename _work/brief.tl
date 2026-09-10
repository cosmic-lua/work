--- `brief`: emit the prompt a subagent runs one role from — builder,
--- research, review, refine, decompose — with every placeholder the board can
--- answer already filled: the item's id, handle, title, spec sidecar
--- verbatim, repo and base branch, the item branch, the exact product
--- commit under review, and this checkout's own absolute path. Templates are
--- `_work.brieftext` and `_work.brieftext_review`; `review` picks
--- between full and mechanical exact-head reviews; the fill grammar is
--- `<UPPER_SNAKE>`, and a placeholder the board cannot answer (a
--- worktree path, a bounce paragraph) survives the fill — the closing
--- verdict line names each survivor, so the caller's whole job is
--- those and pasting the body verbatim.
---
--- Every brief also mints and fills the session label this kind's own
--- claim belongs under (`mint_label`) and repeats it on the closing
--- verdict line, so the orchestrator claims — `take ID --session
--- <label>` — under the exact string the brief just printed, before
--- ever spawning the agent the body is handed to.
---
--- Every body also carries `_work.brieftext_friction`'s `ASK` after
--- its own "Final report" section, unconditionally — the friction ask
--- rides with the brief instead of an orchestrator appending it by
--- hand.
---
--- A read, not a mutation: nothing here writes the board.
local brief_label = require("_work.brief_label")
local brieftext = require("_work.brieftext")
local receipt = require("_work.preparation_receipt")
local brieftext_friction = require("_work.brieftext_friction")
local brieftext_review = require("_work.brieftext_review")
local child = require("cosmic.child")
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

-- Compatibility formatter: history-aware numbering belongs only to cmd_brief.
local mint_label = brief_label.mint_label

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
--- first-seen order, each once. Used both on a raw template (to find
--- the placeholders it declares) and, in the test below, on an
--- already-filled string.
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
--- verbatim (`<N>`, `<ID>`, `<REVIEW_SESSION>` as example command
--- syntax or old-name prose) rides inside `values["SPEC"]`'s own text;
--- since only names the template itself declares are ever candidates,
--- and a candidate survives only when `values` truly holds no answer
--- for it, such a token can never be mistaken for one the caller still
--- owes a fill, no matter where in the body it ends up appearing.
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
--- `*_test.tl` file (there may be none at all), or the diff totals
--- fewer than 20 changed lines — either alone is enough.
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

--- Inspect a handed-over change using only the caller-managed local product
--- checkout. Failure to resolve the mapping merely selects the full review:
--- it never triggers a fetch, credential lookup, or provider request.
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

--- Rework context contains only facts the board actually owns: the verdict
--- kind and commit id. Review prose and provider comments are caller state,
--- never evidence reconstructed by gitboard.
local function bounce_context(it: item.Item, branch?: string): string
  if (it.verdict or "") ~= "request changes" then return "" end
  return fill(brieftext.REWORK, {
      JUDGED_HEAD = it.verdict_head or "",
      BRANCH = branch or it.id:sub(1, 8),
    })
end

--- `<PRODUCT_ROOT>`: the checkout holding `bin/gitboard`. The first
--- attempt is `GITBOARD_DIR`'s parent's parent — `bin/gitboard` exports
--- `GITBOARD_DIR` as `<root>/o/board` in the cold-start bootstrap, so
--- that guess is right and cheap for the common case. It is wrong in
--- the documented sibling-reuse bootstrap, where `GITBOARD_DIR` is
--- instead set to a sibling clone's own root (never `<root>/o/board`):
--- there the guess lands somewhere with no `bin/gitboard` at all —
--- verified by checking for that file rather than trusting the
--- arithmetic. When the guess fails that check, fall back to searching
--- upward from this process's OWN working directory (always a real
--- product checkout — that's what `bin/gitboard` was invoked from) for
--- the nearest ancestor holding `bin/gitboard`. "" when neither the
--- guess nor the search finds one — `GITBOARD_DIR` unset included —
--- leaving the placeholder for the caller to fill, the same way
--- `<WORKTREE>` survives when the board cannot answer it.
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

--- Collect the Teal paths named by the item's `## Change` section, once
--- each and in first-seen order.
local function change_paths(spec: string): {string}
  local paths: {string} = {}
  local seen: {string: boolean} = {}
  local in_change = false
  for line in (spec .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^##%s+Change%s*$") ~= nil then
      in_change = true
    elseif in_change and line:match("^##%s+") ~= nil then
      break
    elseif in_change then
      for path in line:gmatch("[A-Za-z0-9_./-]+%.tl") do
        if not seen[path] then
          seen[path] = true
          paths[#paths + 1] = path
        end
      end
    end
  end
  return paths
end

--- Measure the Change paths from a caller-provided product checkout.
--- @param spec string The item's spec sidecar
--- @param tree string The checkout to measure beneath
--- @return string | nil The appended section, or nil on failure
--- @return string The failure detail, empty on success
local function measure_change(spec: string, tree: string): string | nil, string
  local rev, rerr = child.run({"git", "rev-parse", "--short", "HEAD"},
    {cwd = tree})
  if rev == nil then
    return nil, rerr or "could not resolve the tree's HEAD"
  end
  if not rev.ok then
    return nil, (rev.stderr or "could not resolve the tree's HEAD")
  end
  local head = rev.stdout:match("%S+") or ""
  if head == "" then
    return nil, "the tree's HEAD was empty"
  end
  local rows: {string} = {}
  for _, path in ipairs(change_paths(spec)) do
    local full = fs.join(tree, path)
    if not fs.is_file(full) then
      rows[#rows + 1] = path .. "  absent"
    else
      local operand = path
      if path:sub(1, 1) == "-" then
        operand = "./" .. path
      end
      local count, werr = child.run({"wc", "-l", operand}, {cwd = tree})
      if count == nil then
        return nil, werr or ("could not count " .. path)
      end
      if not count.ok then
        return nil, (count.stderr or ("could not count " .. path))
      end
      local n = math.tointeger(tonumber(count.stdout:match("%d+")))
      if n == nil then
        return nil, "wc returned no line count for " .. path
      end
      local marker = ""
      if n <= 500 and 500 - n <= 40 then
        marker = (" (%d under the 500 cap)"):format(500 - n)
      elseif n > 500 then
        marker = (" (%d over the 500 cap)"):format(n - 500)
      end
      rows[#rows + 1] = ("%s  %d lines%s"):format(path, n, marker)
    end
  end
  return ("## Measured at brief time (%s, %s)\n%s"):format(tree, head,
    table.concat(rows, "\n")), ""
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
--- @return integer Exit code
local function cmd_brief(s: store.Store, kind: string, id: string,
    out?: string, tree?: string, receipt_file?: string, caller?: string): integer
  out = out or ""
  tree = tree or ""
  local template = KINDS[kind or ""]
  if template == nil then
    return gate.verdict_line("brief", false,
      ("unknown brief '%s' — one of: %s"):format(tostring(kind), KIND_LIST))
  end
  if tree ~= "" and not fs.is_dir(tree) then
    return gate.verdict_line("brief", false,
      ("--tree '%s' must be a directory"):format(tree))
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
  end
  local label = ""
  if prep.session ~= nil then
    label = prep.session
  elseif kind == "review" then
    local review_label, err = brief_label.review(s, it.id)
    if review_label == nil then
      return gate.verdict_line("brief", false, err)
    end
    label = review_label
  else
    label = mint_label(kind, tail.bare(it.id))
  end
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
  }
  local root = prep.session == nil and product_root() or ""
  if root ~= "" then
    values["PRODUCT_ROOT"] = root
    -- `<WORKTREE>`: `worktree ID` (run after `take ID`) already made
    -- the builder's checkout at exactly this path, so a builder brief
    -- fills it only once that worktree exists on disk — the same
    -- "unfilled until the board can answer it" rule every other
    -- placeholder follows. A review fills it only when the selected
    -- template contains the placeholder.
    local id8 = it.id:sub(1, 8)
    local wt = fs.join(fs.dirname(root), "wt", id8)
    if kind == "builder" and fs.is_dir(wt) then
      values["WORKTREE"] = wt
    elseif kind == "review" and template:find("<WORKTREE>", 1, true) ~= nil then
      values["WORKTREE"] = fs.join(fs.dirname(root), "wt", "review-" .. id8)
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
  local body = fill(template, values)
  local measured = false
  if tree ~= "" and (kind == "builder" or kind == "review") then
    local section, merr = measure_change(spec, tree)
    if section == nil then
      return gate.verdict_line("brief", false,
        ("could not measure --tree '%s': %s"):format(tree, merr))
    end
    body = body .. "\n\n" .. section
    measured = true
  end
  body = body .. "\n\n" .. brieftext_friction.ASK
  local left = survivors(template, values)
  local session_phrase = prep.session ~= nil and "prepared session" or "claim it as"
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
    return gate.verdict_line("brief",
      true, ("%s brief for %s written to %s, %s %s — %s"):format(
        kind, tail.handle(it.id), out, session_phrase, label, tail_note))
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
  return gate.verdict_line("brief",
    true, ("%s brief for %s, %s %s — %s"):format(
      kind, tail.handle(it.id), session_phrase, label, tail_note))
end

local record brief
  fill: function(text: string, values: {string: string}): string
  unfilled: function(text: string): {string}
  mint_label: function(kind: string, handle: string): string
  cmd_brief: function(s: store.Store, kind: string, id: string, out?: string,
  tree?: string, receipt_file?: string, caller?: string): integer
end

local M: brief = {
  fill = fill,
  unfilled = unfilled,
  mint_label = mint_label,
  cmd_brief = cmd_brief,
}

return M
