--- `brief`: emit the prompt a subagent runs one role from — builder,
--- research, review, refine, decompose — with every placeholder the board
--- can answer already filled: id, handle, title, spec sidecar verbatim,
--- repo/base/item branch, the exact handed-over commit, this checkout's
--- own path. Templates are `_work.brieftext` and `_work.brieftext_review`;
--- `review` picks between full and mechanical reviews of a product
--- commit, and the full review with the findings of a board commit
--- for a research handover.
--- Each template is compiled at build time into a typed renderer
--- (`_work.brieftmpl`, from `_work/brieftmpl_gen.tl`) over a
--- `_work.briefctx` record, so every field a template names is checked
--- against that record rather than looked up by string. A field the
--- board cannot answer (a worktree path, a bounce paragraph) renders
--- as its own `<UPPER_SNAKE>` caller-fill token — `_work.briefcontext`
--- resolves that and records it — and the closing verdict line names
--- each survivor, so the caller's whole job is those and pasting the
--- body verbatim.
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
local briefcontext = require("_work.briefcontext")
local briefmeasure = require("_work.briefmeasure")
local brieftext = require("_work.brieftext")
local gitinvocation = require("_work.gitinvocation")
local receipt = require("_work.preparation_receipt")
local brieftext_friction = require("_work.brieftext_friction")
local child = require("cosmic.child")
local claim = require("_work.claim")
local claimbatch = require("_work.claimbatch")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local gate = require("_work.gitgate")
local gitreadlog = require("_work.gitreadlog")
local item = require("_work.item")
local repository_map = require("_work.repository_map")
local spec = require("_work.spec")
local store = require("_work.store")
local tail = require("_work.tail")

--- The kinds a brief can be asked for, as a set: which renderer each
--- one reaches for is `cmd_brief`'s own dispatch, since the six
--- templates take six different context records.
local KINDS < const >: {string: boolean} = {
  builder = true,
  research = true,
  review = true,
  refine = true,
  decompose = true,
}

--- The kind names, alphabetical, for refusals and help.
local KIND_LIST < const > = "builder, decompose, refine, research, review"

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

--- The findings a research handover hands over: the message body of
--- the board commit `take ID --result` recorded in `it.result` — the
--- item's own tip at that moment, which is the `log ID --add FILE`
--- entry that wrote them. Read through the one reader of commit
--- messages the store has, so the tool's own trailers are already
--- stripped. Refused, rather than rendered empty, when `result` names
--- no commit (a legacy spec-blob digest: `git log` of a blob prints
--- nothing, of an unknown object fails, and neither yields an entry
--- with this sha) or a commit whose body carries no prose — a review
--- with nothing to judge is not a brief.
--- @param s store.Store The store
--- @param it item.Item The item under brief, `result` set
--- @return string | nil The findings
--- @return string The refusal
local function research_findings(s: store.Store, it: item.Item): string | nil, string
  local sha = it.result or ""
  local id8 = it.id:sub(1, 8)
  local entries, _herr = gitreadlog.read_history(s.root, {sha})
  local found: gitreadlog.Entry | nil = nil
  for _, e in ipairs(entries or {}) do
    if e.sha == sha then
      found = e
    end
  end
  if found == nil then
    return nil, ("%s's research result %s is not a board commit — a legacy "
      .. "spec digest; hand the research over again with `take %s --result` "
      .. "to re-type it"):format(id8, sha:sub(1, 12), id8)
  end
  if found.body == "" then
    return nil, ("%s's research handover %s carries no findings in its message "
      .. "body — record them with `log %s --add FILE`, then hand over again "
      .. "with `take %s --result`"):format(id8, sha:sub(1, 12), id8, id8)
  end
  return found.body, ""
end

--- Rework context contains only facts the board actually owns: the
--- verdict kind and commit id, never review prose reconstructed by gitboard.
--- `branch` "" leaves `<BRANCH>` in the spliced text as the caller's to
--- fill — never a guessed identifier.
--- @param it item.Item The item under brief
--- @param branch string The claim's branch, "" when none can be derived
--- @return string The rework section, "" when the item is not in rework
local function bounce_context(it: item.Item, branch: string): string
  if (it.verdict or "") ~= "request changes" then return "" end
  return briefcontext.rework(it.verdict_head or "", branch)
end

--- The checkout holding `bin/gitboard` — what `<PRODUCT_ROOT>` means to
--- a refine or decompose brief, whose every use of it is `cd
--- <PRODUCT_ROOT>` to run that trust root. The first
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

--- `<PRODUCT_ROOT>` for a review: the checkout of the ITEM's own
--- repository, resolved through the ordinary `gitboard.repository` map.
--- A review reads the diff there and passes it as `--repo-dir`, and both
--- are about the repository the change was written for — not necessarily
--- the one the running `bin/gitboard` was invoked from, which is a tree
--- the diff's files need not exist in at all. Falls back to that
--- checkout when the item's repo has no local mapping, unless
--- `map_only`: `REVIEW_SCRIPT`'s `--repo-dir` relies on the fallback
--- when gitboard runs from the unmapped product checkout itself, while a
--- research review names the checkout as the one the `gitboard.repository`
--- map places the item's repository at — gitboard's own checkout rendered
--- under that sentence would be a false claim, so the token survives for
--- the caller instead.
--- @param s store.Store The store
--- @param it item.Item The item under brief
--- @param map_only boolean Never fall back to gitboard's own checkout
--- @return string The checkout's absolute path, "" if unknown
local function review_product_root(s: store.Store, it: item.Item,
    map_only: boolean): string
  local checkout, _cerr = repository_map.resolve(s.root, it.repo or "", "")
  if checkout ~= nil then
    return checkout
  end
  if map_only then
    return ""
  end
  return product_root()
end

--- The claim's actual branch: the same `work/<handle>/<claim>` string
--- `worktree` creates and `gitboard-worktree`'s own verdict line
--- prints. Fixed once the claim exists — `claim.branch` depends only
--- on the item id and the claim batch's root commit, never on whether
--- `worktree ID` has made the directory yet, so this never touches the
--- filesystem (contrast `worktree_path` below). "" when the item has
--- no claim batch or its batch no longer holds a claim.
--- @param s store.Store The store
--- @param it item.Item The item under brief
--- @return string The branch, "" when it cannot be derived
local function claim_branch(s: store.Store, it: item.Item): string
  local pointer = it.claim_batch or ""
  if pointer == "" then return "" end
  local st, _serr = claimbatch.read_state(s.root, pointer, it.id)
  if st == nil then return "" end
  return claim.branch(it.id, st.root)
end

--- The checkout `worktree ID` makes for this item's claim: the same
--- `<checkout>/../wt/<branch>` path `_work.gitworktree` builds, from
--- `claim_branch` above and the same repository map. "" when the
--- branch cannot be derived, or no local checkout is mapped for its
--- repo.
--- @param s store.Store The store
--- @param it item.Item The item under brief
--- @return string The worktree path, "" when it cannot be derived
local function worktree_path(s: store.Store, it: item.Item): string
  local br = claim_branch(s, it)
  if br == "" then return "" end
  local checkout, _cerr = repository_map.resolve(s.root, it.repo or "", "")
  if checkout == nil then return "" end
  return claim.worktree(checkout, br)
end

--- brief: print one role's prompt for an item, resolved from the board.
--- The body prints first and the verdict line closes it (the `show`
--- shape), naming the caller-fill tokens left for the caller. `out`,
--- when given, writes the body to that file instead of printing
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
  if not KINDS[kind or ""] then
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
  local spec_body = spec.document(store.read_spec(s, id))
  if spec_body == "" and kind ~= "decompose" then
    return gate.verdict_line("brief", false,
      ("%s has no spec sidecar — a %s brief carries the spec verbatim, "
        .. "so refine it first"):format(id:sub(1, 8), kind))
  end
  -- A review judges a commit. Which repository that commit lives in
  -- follows from the item's deliverable: a diff hands over a product
  -- commit (`handover_head`, read in the product checkout), research
  -- hands over board state (`result`, a commit on the item's own ref
  -- whose message body is the findings). With both recorded the
  -- product commit is the handover, as `take --head` itself decides.
  local head_sha = ""
  local mechanical = false
  local findings: string | nil = nil
  if kind == "review" then
    if (it.handover_head or "") ~= "" then
      head_sha = it.handover_head or ""
      mechanical = local_mechanical_diff(s, it)
    elseif (it.result or "") ~= "" then
      -- The full review, selected outright: the mechanical probe runs
      -- `git diff` in the product checkout, where a board commit would
      -- make it answer "not mechanical" by accident, not by decision.
      local body, ferr = research_findings(s, it)
      if body == nil then
        return gate.verdict_line("brief", false, ferr)
      end
      head_sha = it.result or ""
      findings = body
    else
      return gate.verdict_line("brief", false,
        ("%s has no handover recorded — `take %s --head SHA` is what "
          .. "a commit review judges"):format(id:sub(1, 8), id:sub(1, 8)))
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
  local facts: briefcontext.Facts = {
    preparation = prep.session ~= nil and receipt.context(prep) or brieftext.BUILDER_PREPARATION,
    item_id = it.id,
    handle = tail.handle(it.id),
    title = it.title,
    worktree = prep.worktree,
    spec = spec_body,
    current_spec = spec_body ~= "" and spec_body
    or "(the item has no spec sidecar)",
    board_dir = fs.absolute_path(s.root),
    review_session = label,
    round_context = "",
    claim_base = prep["product-base"] or it.claim_base or "",
    change_source = (it.external_url or "") ~= ""
    and (("Commit: `%s`\nExternal link (navigation only): %s")
      :format(head_sha, it.external_url or ""))
    or (("Commit: `%s`"):format(head_sha)),
    gitboard_cmd = gitinvocation.prefix(gitboard_command, gitboard_cwd),
  }
  if prep.session == nil then
    local root = kind == "review" and review_product_root(s, it, findings ~= nil)
    or product_root()
    if root ~= "" then
      facts.product_root = root
    end
  end
  -- `<WORKTREE>`: resolves once `worktree ID` (or `--review`) has made
  -- the checkout on disk — unresolved until then, like any other field
  -- the board cannot yet answer. `REVIEW_SCRIPT` declares no worktree.
  if kind == "builder" or (kind == "review" and not mechanical) then
    local wt = worktree_path(s, it)
    if wt ~= "" and fs.is_dir(wt) then
      facts.worktree = wt
    end
  end
  if kind == "builder" then
    -- `<BRANCH>`: the claim's own branch, never the item id's leading
    -- characters — those are a plausible-looking KSUID prefix, not a
    -- ref anything resolves. Unresolved, like `<WORKTREE>`, until a
    -- claim exists to derive it from.
    local br = prep.branch or claim_branch(s, it)
    if br ~= "" then
      facts.branch = br
    end
    local bc = bounce_context(it, br)
    if bc ~= "" then
      facts.bounce_context = bc
    end
  end
  if (it.repo or "") ~= "" then
    facts.repo = it.repo
  end
  if head_sha ~= "" then
    facts.head_sha = head_sha
  end
  if findings ~= nil then
    facts.findings = findings
  end
  local body: string = ""
  local left: {string} = {}
  if kind == "builder" or kind == "review" then
    local checkout, _cerr = repository_map.resolve(s.root, it.repo or "", "")
    local cmds = briefcommands.commands(checkout or "", kind)
    if kind == "builder" then
      body, left = briefcontext.builder(facts, cmds)
    elseif mechanical then
      body, left = briefcontext.review_script(facts, cmds)
    else
      body, left = briefcontext.review(facts, cmds)
    end
  elseif kind == "research" then
    body, left = briefcontext.research(facts)
  elseif kind == "refine" then
    body, left = briefcontext.refine(facts)
  else
    body, left = briefcontext.decompose(facts)
  end
  local measured = false
  if tree ~= "" and (kind == "builder" or kind == "review") then
    local section, merr = briefmeasure.measure(spec_body, tree)
    if section == nil then
      return gate.verdict_line("brief", false,
        ("could not measure --tree '%s': %s"):format(tree, merr))
    end
    body = body .. "\n\n" .. section
    measured = true
  end
  body = body .. "\n\n" .. brieftext_friction.ASK
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
  cmd_brief: function(s: store.Store, kind: string, id: string, out?: string,
  tree?: string, receipt_file?: string, caller?: string,
  gb_command?: string, gb_cwd?: string): integer
end

local M: brief = {
  cmd_brief = cmd_brief,
}

return M
