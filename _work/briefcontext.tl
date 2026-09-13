--- What a brief's typed context is resolved from, and the one place a
--- field the board cannot answer becomes visible output.
---
--- `_work.brief` gathers the board's facts into one `Facts` record —
--- every value it could resolve, `nil` for every one it could not —
--- and each function here turns that into the concrete
--- `_work.briefctx` record its template's compiled renderer takes.
--- The renderers do no resolution of their own: `cosmic.template`
--- compiles an interpolation into a plain typed read (`local v:
--- string = d.item_id`), so there is no such thing as a missing field
--- at render time.
---
--- The three states a field can be in, and how each is modelled:
---
---   * ABSENT — the board cannot answer it (no worktree on disk yet,
---     no caller invocation supplied). The field renders as its own
---     caller-fill token, `<WORKTREE>`, exactly as an unfilled
---     placeholder used to survive, and the token is recorded as a
---     survivor for the verdict line to name.
---   * INTENTIONALLY EMPTY — the board answers it with "". It renders
---     as nothing and is NOT a survivor: `round_context` is always
---     this, and a `bootstrap_cmd` for a repo advertising no bootstrap
---     step is too.
---   * SUPPLIED — any other text, rendered verbatim. A spec whose own
---     prose contains `<SPEC>`, `{{.spec}}`, a percent sign or a
---     Markdown fence is data like any other: absence is recorded from
---     the RESOLUTION, never inferred from the rendered body, so no
---     value's own text can make it look unresolved.
---
--- Survivor ORDER is the template's own first-seen field order, read
--- off the template at build time by `_work/brieftmpl_gen.tl` into
--- `_work.brieftmpl.fields` — the same order a scan of the raw
--- template used to produce, without the scan. A brief that splices a
--- sub-render in with its OWN tracker (the full review's two sections)
--- reports in the order the rendered brief first sees each token: the
--- spliced unit's tokens stand where its splice is, each once.

local briefcommands = require("_work.briefcommands")
local briefctx = require("_work.briefctx")
local fields = require("_work.brieftmpl.fields")
local tmpl_builder = require("_work.brieftmpl.builder")
local tmpl_decompose = require("_work.brieftmpl.decompose")
local tmpl_posture_diff = require("_work.brieftmpl.posture_diff")
local tmpl_posture_research = require("_work.brieftmpl.posture_research")
local tmpl_refine = require("_work.brieftmpl.refine")
local tmpl_research = require("_work.brieftmpl.research")
local tmpl_review = require("_work.brieftmpl.review")
local tmpl_review_script = require("_work.brieftmpl.review_script")
local tmpl_reviewing_diff = require("_work.brieftmpl.reviewing_diff")
local tmpl_reviewing_research = require("_work.brieftmpl.reviewing_research")
local tmpl_rework = require("_work.brieftmpl.rework")

--- The caller-fill tokens one brief could not resolve, as a set. Kept
--- per render rather than per process: a spliced sub-render (the
--- rework section) tracks its own, and its unresolved fields are not
--- the outer brief's to report.
local record Tracker
  absent: {string: boolean}
end

--- Every board fact a brief can carry, resolved once by `_work.brief`
--- and shared by the kinds that declare each one. A field typed
--- `string | nil` is one the board may be unable to answer; a plain
--- `string` is always resolved, "" included. `findings` is the one
--- exception to that reading: nil means the review's deliverable is a
--- diff, not that the board could not answer — a research handover's
--- findings are the message body of `head_sha` on the board, and a
--- review carrying them takes the research wording.
local record Facts
  repo: string | nil
  worktree: string | nil
  branch: string | nil
  bounce_context: string | nil
  product_root: string | nil
  head_sha: string | nil
  findings: string | nil
  preparation: string
  board_dir: string
  item_id: string
  handle: string
  title: string
  spec: string
  current_spec: string
  review_session: string
  round_context: string
  claim_base: string
  change_source: string
  gitboard_cmd: string
end

--- A fresh survivor set for one render.
--- @return Tracker The tracker
local function tracker(): Tracker
  return {absent = {}}
end

--- The text one field renders as.
--- @param tr Tracker The render's survivor set
--- @param token string The field's caller-fill token, `<WORKTREE>`
--- @param value string | nil The resolved value, nil when unresolved
--- @return string The value, or the token when there is none
local function need(tr: Tracker, token: string, value: string | nil): string
  if value == nil then
    tr.absent[token] = true
    return token
  end
  return value
end

--- The tokens `tr` recorded, in the template's own declared order.
--- @param declared {string} The template's tokens, first-seen order
--- @param tr Tracker The render's survivor set
--- @return {string} The unresolved tokens, possibly empty
local function survivors(declared: {string}, tr: Tracker): {string}
  local out: {string} = {}
  for _, token in ipairs(declared) do
    if tr.absent[token] then
      out[#out + 1] = token
    end
  end
  return out
end

--- `outer`'s tokens with each splice's own tokens standing where its
--- splice token is — the order a brief whose sections are rendered on
--- their own first sees each token. A token both sides declare (the
--- review's head) is listed once, where it is first seen.
--- @param outer {string} The enclosing template's declared tokens
--- @param splices {string: {string}} Splice token to the unit's tokens
--- @return {string} The expanded order, each token once
local function spliced_order(outer: {string}, splices: {string: {string}}): {string}
  local seen: {string: boolean} = {}
  local out: {string} = {}
  local function add(token: string)
    if not seen[token] then
      seen[token] = true
      out[#out + 1] = token
    end
  end
  for _, token in ipairs(outer) do
    local inner = splices[token]
    if inner ~= nil then
      for _, t in ipairs(inner) do
        add(t)
      end
    else
      add(token)
    end
  end
  return out
end

--- The rework section a builder brief splices into `bounce_context`.
---
--- Rendered on its own, with its own tracker: `<WORKTREE>` here is
--- always the caller's to fill and `<BRANCH>` is whenever no claim
--- branch exists yet, but neither is a field of the BUILDER template,
--- so neither is ever reported as that brief's survivor. What this
--- returns is data to the outer render, never template source.
--- @param judged_head string The commit the request-changes verdict judged
--- @param branch string The claim's branch, "" when it cannot be derived
--- @return string The rendered section
local function rework(judged_head: string, branch: string): string
  local tr = tracker()
  return tmpl_rework.render({
      judged_head = judged_head,
      worktree = need(tr, "<WORKTREE>", nil),
      branch = need(tr, "<BRANCH>", branch ~= "" and branch or nil),
    })
end

--- @param f Facts The board's resolved facts
--- @param cmds briefcommands.Commands The item's repo-mechanics commands
--- @return string The rendered builder brief
--- @return {string} The tokens it left for the caller
local function builder(f: Facts, cmds: briefcommands.Commands): string, {string}
  local tr = tracker()
  local d: briefctx.Builder = {
    repo = need(tr, "<REPO>", f.repo),
    worktree = need(tr, "<WORKTREE>", f.worktree),
    branch = need(tr, "<BRANCH>", f.branch),
    preparation = f.preparation,
    board_dir = f.board_dir,
    item_id = f.item_id,
    handle = f.handle,
    title = f.title,
    bounce_context = need(tr, "<BOUNCE_CONTEXT>", f.bounce_context),
    spec = f.spec,
    type_check_cmd = cmds.type_check_cmd,
    test_cmd = cmds.test_cmd,
    gate_cmd = cmds.gate_cmd,
    bootstrap_cmd = need(tr, "<BOOTSTRAP_CMD>", cmds.bootstrap_cmd),
    gitboard_cmd = f.gitboard_cmd,
  }
  return tmpl_builder.render(d), survivors(fields.builder, tr)
end

--- @param f Facts The board's resolved facts
--- @return string The rendered research brief
--- @return {string} The tokens it left for the caller
local function research(f: Facts): string, {string}
  local tr = tracker()
  local d: briefctx.Research = {
    repo = need(tr, "<REPO>", f.repo),
    worktree = need(tr, "<WORKTREE>", f.worktree),
    item_id = f.item_id,
    handle = f.handle,
    title = f.title,
    bounce_context = need(tr, "<BOUNCE_CONTEXT>", f.bounce_context),
    spec = f.spec,
  }
  return tmpl_research.render(d), survivors(fields.research, tr)
end

--- @param f Facts The board's resolved facts
--- @return string The rendered refine brief
--- @return {string} The tokens it left for the caller
local function refine(f: Facts): string, {string}
  local tr = tracker()
  local d: briefctx.Refine = {
    product_root = need(tr, "<PRODUCT_ROOT>", f.product_root),
    item_id = f.item_id,
    handle = f.handle,
    title = f.title,
    gap = need(tr, "<GAP>", nil),
    current_spec = f.current_spec,
  }
  return tmpl_refine.render(d), survivors(fields.refine, tr)
end

--- @param f Facts The board's resolved facts
--- @return string The rendered decompose brief
--- @return {string} The tokens it left for the caller
local function decompose(f: Facts): string, {string}
  local tr = tracker()
  local d: briefctx.Decompose = {
    product_root = need(tr, "<PRODUCT_ROOT>", f.product_root),
    item_id = f.item_id,
    handle = f.handle,
    title = f.title,
    gap = need(tr, "<GAP>", nil),
    current_spec = f.current_spec,
  }
  return tmpl_decompose.render(d), survivors(fields.decompose, tr)
end

--- The "what you're reviewing" section a full review splices in: the
--- research wording when `f.findings` is set, the diff wording
--- otherwise. Rendered with the review's own tracker, since
--- `<HEAD_SHA>` is a field the review template declares too.
--- @param tr Tracker The review's survivor set
--- @param f Facts The board's resolved facts
--- @return string The rendered section
local function reviewing(tr: Tracker, f: Facts): string
  local head_sha = need(tr, "<HEAD_SHA>", f.head_sha)
  if f.findings ~= nil then
    return tmpl_reviewing_research.render({
        board_dir = f.board_dir,
        head_sha = head_sha,
        findings = f.findings,
      })
  end
  return tmpl_reviewing_diff.render({
      claim_base = f.claim_base,
      head_sha = head_sha,
    })
end

--- The "how to review" section and verdict lines a full review splices
--- in: the research wording when `f.findings` is set — what a findings
--- review checks, verdict lines naming no checkout — and the diff
--- wording otherwise, the mutation step from the reviewer's own
--- worktree and `--repo-dir` on every verdict line. Rendered with the
--- review's own tracker: the worktree and bootstrap plan a diff review
--- owes are the review's survivors, and a research review owes neither.
--- @param tr Tracker The review's survivor set
--- @param f Facts The board's resolved facts
--- @param cmds briefcommands.Commands The item's repo-mechanics commands
--- @return string The rendered section
local function posture(tr: Tracker, f: Facts, cmds: briefcommands.Commands): string
  local head_sha = need(tr, "<HEAD_SHA>", f.head_sha)
  if f.findings ~= nil then
    return tmpl_posture_research.render({
        head_sha = head_sha,
        board_dir = f.board_dir,
        review_session = f.review_session,
        gitboard_cmd = f.gitboard_cmd,
        item_id = f.item_id,
      })
  end
  return tmpl_posture_diff.render({
      head_sha = head_sha,
      test_cmd_phrase = cmds.test_cmd_phrase,
      worktree = need(tr, "<WORKTREE>", f.worktree),
      board_dir = f.board_dir,
      review_session = f.review_session,
      bootstrap_phrase = need(tr, "<BOOTSTRAP_PHRASE>", cmds.bootstrap_phrase),
      gitboard_cmd = f.gitboard_cmd,
      item_id = f.item_id,
    })
end

--- @param f Facts The board's resolved facts
--- @param cmds briefcommands.Commands The item's repo-mechanics commands
--- @return string The rendered full review brief
--- @return {string} The tokens it left for the caller
local function review(f: Facts, cmds: briefcommands.Commands): string, {string}
  local tr = tracker()
  local is_research = f.findings ~= nil
  local d: briefctx.Review = {
    repo = need(tr, "<REPO>", f.repo),
    item_id = f.item_id,
    handle = f.handle,
    title = f.title,
    change_source = f.change_source,
    reviewing = reviewing(tr, f),
    spec = f.spec,
    round_context = f.round_context,
    posture = posture(tr, f, cmds),
    gitboard_cmd = f.gitboard_cmd,
  }
  local declared = spliced_order(fields.review, {
      ["<REVIEWING>"] = is_research and fields.reviewing_research or fields.reviewing_diff,
      ["<POSTURE>"] = is_research and fields.posture_research or fields.posture_diff,
    })
  return tmpl_review.render(d), survivors(declared, tr)
end

--- @param f Facts The board's resolved facts
--- @param cmds briefcommands.Commands The item's repo-mechanics commands
--- @return string The rendered mechanical review brief
--- @return {string} The tokens it left for the caller
local function review_script(f: Facts, cmds: briefcommands.Commands): string, {string}
  local tr = tracker()
  local d: briefctx.ReviewScript = {
    repo = need(tr, "<REPO>", f.repo),
    item_id = f.item_id,
    handle = f.handle,
    title = f.title,
    change_source = f.change_source,
    board_dir = f.board_dir,
    claim_base = f.claim_base,
    head_sha = need(tr, "<HEAD_SHA>", f.head_sha),
    spec = f.spec,
    product_root = need(tr, "<PRODUCT_ROOT>", f.product_root),
    review_session = f.review_session,
    bootstrap_phrase = need(tr, "<BOOTSTRAP_PHRASE>", cmds.bootstrap_phrase),
    gitboard_cmd = f.gitboard_cmd,
  }
  return tmpl_review_script.render(d), survivors(fields.review_script, tr)
end

local record briefcontext
  type Facts = Facts
  type Tracker = Tracker
  tracker: function(): Tracker
  need: function(tr: Tracker, token: string, value: string | nil): string
  survivors: function(declared: {string}, tr: Tracker): {string}
  rework: function(judged_head: string, branch: string): string
  builder: function(f: Facts, cmds: briefcommands.Commands): string, {string}
  research: function(f: Facts): string, {string}
  refine: function(f: Facts): string, {string}
  decompose: function(f: Facts): string, {string}
  review: function(f: Facts, cmds: briefcommands.Commands): string, {string}
  review_script: function(f: Facts, cmds: briefcommands.Commands): string, {string}
end

local M: briefcontext = {
  tracker = tracker,
  need = need,
  survivors = survivors,
  rework = rework,
  builder = builder,
  research = research,
  refine = refine,
  decompose = decompose,
  review = review,
  review_script = review_script,
}

return M
