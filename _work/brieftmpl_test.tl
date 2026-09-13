#!/usr/bin/env cosmic
-- The compiled brief renderers and the resolution around them: that
-- the generated directory holds one renderer per template and nothing
-- else, that a field the board cannot answer renders as its own
-- caller-fill token and is reported while an intentionally empty one
-- is neither, and that text spliced into a field is data — never
-- reinterpreted as template syntax, whatever it happens to contain.
--
-- Whether those renderers are what their templates compile to is not
-- asked here: `_work/brieftmpl_gen.tl` repairs the tree before the
-- graph on every verb, so by the time a test runs the drift is gone
-- and a comparison would compare the generator against itself. The
-- generator reports what it had to rewrite instead, which is the only
-- place that fact survives.
--
-- The generated directory is listed here rather than required as
-- modules, so the build graph cannot see that this test depends on
-- what it holds; the declaration re-records the result when it changes.
--- reads: _work/brieftmpl

local fs = require("cosmic.fs")
local teal = require("cosmic.teal")
local template = require("cosmic.template")
local briefcommands = require("_work.briefcommands")
local briefcontext = require("_work.briefcontext")
local briefctx = require("_work.briefctx")
local fields = require("_work.brieftmpl.fields")
local round = require("_work.brieftmpl.round")
local source = require("_work.brieftmpl_source")

--- A builder context whose every field is answered, so a test that
--- cares about one field varies only that one.
--- @return briefcontext.Facts The resolved facts
local function full_facts(): briefcontext.Facts
  return {
    repo = "cosmic-lua/work",
    worktree = "/wt/work/abcd",
    branch = "work/abcd/ef01",
    bounce_context = "",
    product_root = "/src/work",
    head_sha = "0123456789abcdef",
    preparation = "It is already bootstrapped.",
    board_dir = "/src/work/o/board",
    item_id = "3JEQZ7UEoFtzblNFG29uOsCKV6H",
    handle = "uOsC_KV6H",
    title = "A title",
    spec = "## Change\n\nDo the thing.\n",
    current_spec = "## Change\n\nDo the thing.\n",
    review_session = "sess-1",
    round_context = "",
    claim_base = "fedcba9876543210",
    change_source = "Commit: `0123456789abcdef`",
    gitboard_cmd = "bin/gitboard",
  }
end

--- Every repo-mechanics command answered.
--- @return briefcommands.Commands The resolved commands
local function full_commands(): briefcommands.Commands
  return {
    type_check_cmd = "`check <file>`",
    test_cmd = "`test <file>`",
    gate_cmd = "`gate`",
    test_cmd_phrase = "`test <file>`",
    bootstrap_cmd = "--make build",
    bootstrap_phrase = "`fetch` before you run any test.",
  }
end

-- The generated directory holds the renderers and nothing else: a
-- renamed template must take its old module with it, or the artifact
-- ships a renderer no template produces.
local function test_generated_directory_holds_exactly_the_templates()
  local want: {string: boolean} = {["fields.tl"] = true}
  for _, u in ipairs(source.UNITS) do
    want[u.name .. ".tl"] = true
  end
  local found = fs.glob(source.OUT_DIR, "*.tl")
  assert(found ~= nil, "the generated directory is missing")
  local seen: {string: boolean} = {}
  for _, path in ipairs(found) do
    local name = fs.basename(path)
    assert(want[name], source.OUT_DIR .. " holds " .. name .. ", which no template produces")
    seen[name] = true
  end
  for name in pairs(want) do
    assert(seen[name], source.OUT_DIR .. " is missing " .. name)
  end
end

-- The declared token list is read off the template itself, so it
-- cannot drift from the fields the template actually interpolates.
local function test_declared_fields_are_the_templates_own_tokens()
  local by_name: {string: {string}} = {
    builder = fields.builder,
    rework = fields.rework,
    research = fields.research,
    refine = fields.refine,
    decompose = fields.decompose,
    review = fields.review,
    review_script = fields.review_script,
    opening_diff = fields.opening_diff,
    opening_research = fields.opening_research,
    reviewing_diff = fields.reviewing_diff,
    reviewing_research = fields.reviewing_research,
    posture_diff = fields.posture_diff,
    posture_research = fields.posture_research,
    round = fields.round,
  }
  for _, u in ipairs(source.UNITS) do
    local declared = by_name[u.name]
    assert(declared ~= nil, u.name .. " declares no field list")
    local want = source.tokens_of(u.text)
    assert(#declared == #want, u.name .. ": " .. #declared .. " fields, " .. #want .. " tokens")
    for i, token in ipairs(want) do
      assert(declared[i] == token,
        u.name .. " field " .. i .. ": " .. declared[i] .. " ~= " .. token)
    end
  end
end

-- Absent, empty, supplied — the three states, at the seam that
-- decides them. An absent value becomes its own caller-fill token and
-- is reported; an empty one renders as nothing and is not.
local function test_absent_renders_its_token_and_is_reported()
  local tr = briefcontext.tracker()
  assert(briefcontext.need(tr, "<WORKTREE>", nil) == "<WORKTREE>")
  local left = briefcontext.survivors({"<WORKTREE>"}, tr)
  assert(#left == 1 and left[1] == "<WORKTREE>", "an absent field is a survivor")
end

local function test_empty_is_supplied_not_absent()
  local tr = briefcontext.tracker()
  assert(briefcontext.need(tr, "<BOOTSTRAP_CMD>", "") == "",
    "an intentionally empty value renders as nothing")
  assert(#briefcontext.survivors({"<BOOTSTRAP_CMD>"}, tr) == 0,
    "an intentionally empty value is not a survivor")
end

-- Absence is recorded from the RESOLUTION, so a value whose own text
-- is the token is still supplied text: nothing scans the rendered body.
local function test_a_value_spelled_like_its_token_is_still_supplied()
  local tr = briefcontext.tracker()
  assert(briefcontext.need(tr, "<SPEC>", "<SPEC>") == "<SPEC>")
  assert(#briefcontext.survivors({"<SPEC>"}, tr) == 0,
    "a value that happens to read like its token is not a survivor")
end

-- Survivors come out in the template's own first-seen order, not in
-- the order the resolution happened to record them.
local function test_survivor_order_is_the_templates_own()
  local f = full_facts()
  f.repo = nil
  f.worktree = nil
  f.branch = nil
  local _body, left = briefcontext.builder(f, full_commands())
  assert(#left == 3, "three fields went unresolved: " .. #left)
  assert(left[1] == "<REPO>" and left[2] == "<WORKTREE>" and left[3] == "<BRANCH>",
    "survivors follow the template's declared order: " .. table.concat(left, " "))
end

-- A prepared builder context answers the worktree and branch itself,
-- so the brief owes the caller nothing.
local function test_a_fully_resolved_builder_leaves_nothing()
  local _body, left = briefcontext.builder(full_facts(), full_commands())
  assert(#left == 0, "nothing is left to fill: " .. table.concat(left, " "))
end

-- An unprepared one leaves exactly the fields the board cannot answer.
local function test_an_unprepared_builder_leaves_its_own_fields()
  local f = full_facts()
  f.worktree = nil
  f.branch = nil
  f.bounce_context = nil
  local body, left = briefcontext.builder(f, full_commands())
  assert(table.concat(left, " ") == "<WORKTREE> <BRANCH> <BOUNCE_CONTEXT>",
    "the unanswered fields, in template order: " .. table.concat(left, " "))
  assert(body:find("<WORKTREE>", 1, true) ~= nil,
    "an unresolved field renders as its own token")
end

-- Text spliced into a field is DATA. Whatever it contains — a token
-- spelled like a placeholder, this grammar's own `{{.field}}` syntax,
-- percent signs, Markdown fences — comes out byte for byte and is
-- never re-read as template source.
local INSERTED < const > = [[
A spec quoting <SPEC> and <CONST_NAME> as old names, {{.spec}} as
grammar, 100% of the time, and a fence:

```teal
local pct = ("%d%%"):format(50)
```
]]

local function test_inserted_text_is_verbatim_and_never_template_syntax()
  local f = full_facts()
  f.spec = INSERTED
  local body, left = briefcontext.builder(f, full_commands())
  assert(body:find(INSERTED, 1, true) ~= nil, "the spec rides the brief verbatim")
  assert(#left == 0, "nothing in the spec's own text is read as an unfilled field")
end

-- The same for a review, whose spec sits in a different template.
local function test_inserted_text_is_verbatim_in_a_review()
  local f = full_facts()
  f.spec = INSERTED
  local body, left = briefcontext.review(f, full_commands())
  assert(body:find(INSERTED, 1, true) ~= nil, "the spec rides the review verbatim")
  assert(#left == 0, "nothing in the spec's own text is read as an unfilled field")
end

-- The mechanical review declares no worktree at all, so an absent one
-- is never reported by it — the two review variants differ in their
-- fields, not in a scan of their text.
local function test_the_mechanical_review_owes_no_worktree()
  local f = full_facts()
  f.worktree = nil
  local body, left = briefcontext.review_script(f, full_commands())
  assert(#left == 0, "the mechanical review has no worktree field: "
    .. table.concat(left, " "))
  assert(body:find("<WORKTREE>", 1, true) == nil, "and renders none")
  local _rbody, rleft = briefcontext.review(f, full_commands())
  assert(table.concat(rleft, " ") == "<WORKTREE>",
    "the full review does owe one: " .. table.concat(rleft, " "))
end

-- The rework section is rendered on its own and spliced in as data:
-- its own unresolved fields belong to the caller, not to the builder
-- brief's survivor list.
local function test_the_rework_section_reports_no_survivors_of_its_own()
  local f = full_facts()
  local section = briefcontext.rework("abc123", "")
  f.bounce_context = section
  local body, left = briefcontext.builder(f, full_commands())
  assert(section:find("<WORKTREE>", 1, true) ~= nil,
    "the rework section leaves its own worktree to the caller")
  assert(section:find("<BRANCH>", 1, true) ~= nil,
    "and its branch, with no claim branch to name")
  assert(body:find("<BRANCH>", 1, true) ~= nil, "spliced in verbatim")
  assert(#left == 0,
    "but the builder brief reports only its OWN fields: " .. table.concat(left, " "))
end

-- The full review's "what you're reviewing" section follows the
-- deliverable: `findings` nil is a diff — the product commit range, the
-- text it always carried — and `findings` set is research: that text
-- verbatim under its own wording, the diff wording gone. The section is
-- spliced with the review's own tracker, so a head the board could not
-- answer is reported once, not once per splice.
local function test_the_review_section_follows_the_deliverable()
  local f = full_facts()
  local diff_body, dleft = briefcontext.review(f, full_commands())
  assert(#dleft == 0, "a diff review answers everything: " .. table.concat(dleft, " "))
  assert(diff_body:find("The caller has made this exact commit available in your local checkout.\n"
      .. "Review `fedcba9876543210..0123456789abcdef`;", 1, true) ~= nil, diff_body)
  assert(diff_body:find("## The spec this PR is supposed to satisfy (verbatim)\n\n---\n"
      .. "## Change\n\nDo the thing.\n\n---", 1, true) ~= nil, diff_body)
  assert(diff_body:find("This is a research handover", 1, true) == nil, diff_body)
  f.findings = "The probe held: three of four."
  local research_body, rleft = briefcontext.review(f, full_commands())
  assert(#rleft == 0, "a research review answers everything: " .. table.concat(rleft, " "))
  assert(research_body:find("This is a research handover", 1, true) ~= nil, research_body)
  assert(research_body:find("the body of `0123456789abcdef`)\n\n---\n"
      .. "The probe held: three of four.\n---\n\n"
      .. "## The spec these findings are supposed to answer (verbatim)\n\n---\n"
      .. "## Change\n\nDo the thing.\n\n---", 1, true) ~= nil, research_body)
  assert(research_body:find("the clone at\n`/src/work/o/board`", 1, true) ~= nil, research_body)
  assert(research_body:find("The caller has made this exact commit", 1, true) == nil
    and research_body:find("Review `fedcba", 1, true) == nil, research_body)
  f.head_sha = nil
  local _body, hleft = briefcontext.review(f, full_commands())
  assert(table.concat(hleft, " ") == "<HEAD_SHA>",
    "the spliced section's head is the review's own survivor, once: "
    .. table.concat(hleft, " "))
end

-- The full review's "how to review" section, verdict lines, `done` line
-- and final report follow the deliverable the same way: `findings` nil
-- is a diff — the adversarial list over the diff, the mutation step
-- from the reviewer's own worktree, `--repo-dir` on every verdict line,
-- `done --landed SHA` after landing, the mutation run in the report,
-- byte for byte what the review always carried, pinned here as rendered
-- through the first line of the paragraph the review still carries
-- itself, and its opening paragraph the same way, pinned from the
-- brief's first byte through the first line the review carries itself —
-- and `findings` set is research: what a findings review
-- checks, reproduced in a worktree added from the product checkout, no
-- diff to list, no guard to mutate, verdict lines naming no checkout,
-- `--landed` the board commit itself, the re-run claims in the report.
-- Spliced with the review's own tracker, so the worktree and bootstrap
-- plan a diff review cannot answer are its survivors, in the rendered
-- brief's own order, and a research review owes neither — only the
-- product checkout it reproduces from.
local DIFF_POSTURE < const > = [[


## How to review — the posture is ADVERSARIAL

Your job is to try to make this diff fail, not to confirm it looks
fine.

1. Confirm you are reading exactly `0123456789abcdef`. If the caller supplies
   external checks, confirm they name that SHA; red or running means stop and
   record nothing. Never infer check state from the board. The caller spawns
   this review only once mechanical checks are green on this exact head (or,
   when CI was unavailable by the item's own design, once the caller ran the
   spec-named guards locally instead) — trust that gate; your job is the
   fresh semantic read and mutation below, not re-verifying CI.
2. The diff is the Change — everything present, nothing extra. List
   the changed files and confirm each is inside the spec's stated
   scope. Anything outside it is scope creep — quote it, even when
   it looks good; good ideas become their own items. When the spec
   states a pattern and a count, re-run `cosmic --find` on the handed-over
   commit from your checkout: the hit list IS the expected change
   set — a hit the diff leaves unchanged, or a changed site outside
   the hits, is a finding.
3. The walls held: every `## Non-goals` line honored, frozen
   contracts unmoved.
4. Conventions hold: the repo's AGENTS.md binds. Anything a gate
   should have caught but did not is itself a finding to report.
5. It serves the outcome: judge the diff against the item's parent
   chain, not just the letter of `## Change`. A green gate on a
   change that misses the point means the SPEC was wrong — say so,
   never wave the diff through.
6. It is the least thing: name any surplus concretely and treat it
   as a gap to quote.

Mutation-test at least one guard the change adds or relies on: break
what it guards, confirm the diff's own test catches it — run the ONE
test file that guards it (`test <file>`), not the suite —
restore it exactly. A real break changes the outcome the test reads,
never just the text around it: replace a matched needle with
unrelated text rather than extending it, flip a boolean rather than
renaming it, and if the test stays green the guard is decoration.
Do this from your own fresh checkout at `/wt/work/abcd` — never reuse
another agent's worktree.
The checkout that holds the board worktree (`/src/work/o/board/..`) is the
orchestrator's and is stale by construction; never read, grep or build
in it. Your worktree is the only tree.

## Recording your verdict

`verdict` verifies and records one local commit id. It performs no fetch,
credential lookup, check read, merge, or provider write. The caller owns
those operations. This review is claimed under session `sess-1` —
you MUST use that exact string. That checkout has no `o/3p` cache yet — run
`fetch` before you run any test.

GitBoard invocation for this review: `bin/gitboard` — the exact
loader and absolute executable the caller runs board commands through.
Use it verbatim as the prefix below; never guess a product-checkout
substitute of your own, and never bootstrap one yourself.

```
bin/gitboard verdict 3JEQZ7UEoFtzblNFG29uOsCKV6H accept \
  --head 0123456789abcdef --session sess-1 --repo-dir /wt/work/abcd
bin/gitboard verdict 3JEQZ7UEoFtzblNFG29uOsCKV6H request-changes \
  --head 0123456789abcdef --session sess-1 --repo-dir /wt/work/abcd
bin/gitboard verdict 3JEQZ7UEoFtzblNFG29uOsCKV6H reject \
  --head 0123456789abcdef --session sess-1 --repo-dir /wt/work/abcd
```

Run exactly the one line matching your judgment. The board stores the SHA,
not review prose. Put concrete gaps in your final report for the caller. An
accept does not merge or complete the item; after landing, the caller runs
`bin/gitboard done 3JEQZ7UEoFtzblNFG29uOsCKV6H --landed SHA`.

## Final report

The verdict you recorded (or why you could not), the mutation-test
you ran and its result, and any concrete findings quoted with
file:line. Keep it factual and concise.

A request-changes verdict names five labeled facts, not a fix: the
]]

local DIFF_OPENING < const > = [[
You are a fresh-context code reviewer for `cosmic-lua/work`. You have never
seen this change before — that is deliberate: the review must come
from a distance from the builder. Everything you need is below.

## What you're reviewing

Board item id: `3JEQZ7UEoFtzblNFG29uOsCKV6H` (handle uOsC_KV6H)
]]

local function test_the_review_posture_follows_the_deliverable()
  local f = full_facts()
  local diff_body, dleft = briefcontext.review(f, full_commands())
  assert(#dleft == 0, "a diff review answers everything: " .. table.concat(dleft, " "))
  assert(diff_body:sub(1, #DIFF_OPENING) == DIFF_OPENING,
    "the diff opening is byte for byte what the review always carried: " .. diff_body)
  assert(diff_body:find(DIFF_POSTURE, 1, true) ~= nil,
    "the diff posture is byte for byte what the review always carried: " .. diff_body)
  assert(diff_body:find("There is no diff here", 1, true) == nil, diff_body)
  f.findings = "The probe held: three of four."
  local research_body, rleft = briefcontext.review(f, full_commands())
  assert(#rleft == 0, "a research review answers everything: " .. table.concat(rleft, " "))
  for _, diff_only in ipairs({"The diff is the Change", "cosmic --find",
      "Mutation-test at least one guard", "fresh checkout", "--repo-dir",
      "/wt/work/abcd", "<WORKTREE>", "o/3p", "`test <file>`",
      "`fetch` before you run any test.", "no product worktree",
      "code reviewer", "seen this change before", "--landed SHA",
      "the mutation-test\nyou ran and its result", "never bootstrap one yourself"}) do
    assert(research_body:find(diff_only, 1, true) == nil,
      "diff wording a research reviewer cannot act on: " .. diff_only .. "\n" .. research_body)
  end
  for _, wanted in ipairs({"the posture is ADVERSARIAL",
      "You are a fresh-context findings reviewer for `cosmic-lua/work`. You have never\n"
      .. "seen these findings before",
      "names its command, and the command reproduces",
      "`git worktree add <dir> <commit>` from the product checkout at\n"
      .. "   `/src/work` — the item's repository, `cosmic-lua/work`, as the\n"
      .. "   caller's `gitboard.repository` map places it — and run there, never\n"
      .. "   in that checkout itself. Bootstrap that worktree the way the product\n"
      .. "   repository's own instructions (its AGENTS.md) bootstrap a new\n"
      .. "   checkout, before the first re-run.",
      "never substitute a `bin/gitboard`\nfrom a product checkout, and never bootstrap "
      .. "that loader yourself — the\nreproduction worktree above is the one tree you "
      .. "bootstrap.",
      "follows from the measurements and not past them",
      "Nothing the spec asked to be measured is missing",
      "prospective evidence for the item's parent chain",
      "stale by construction; never read, grep or build",
      "a research item lands\nnothing — its deliverable is the board commit itself — "
      .. "so the caller runs\n`bin/gitboard done 3JEQZ7UEoFtzblNFG29uOsCKV6H "
      .. "--landed 0123456789abcdef`.\n\n## Final report\n\n"
      .. "The verdict you recorded (or why you could not), each measured claim you\n"
      .. "re-ran and whether it reproduced,"}) do
    assert(research_body:find(wanted, 1, true) ~= nil,
      "what a findings review checks: " .. wanted .. "\n" .. research_body)
  end
  assert(research_body:find("```\nbin/gitboard verdict 3JEQZ7UEoFtzblNFG29uOsCKV6H accept \\\n"
      .. "  --head 0123456789abcdef --session sess-1\n"
      .. "bin/gitboard verdict 3JEQZ7UEoFtzblNFG29uOsCKV6H request-changes \\\n"
      .. "  --head 0123456789abcdef --session sess-1\n"
      .. "bin/gitboard verdict 3JEQZ7UEoFtzblNFG29uOsCKV6H reject \\\n"
      .. "  --head 0123456789abcdef --session sess-1\n```\n\n"
      .. "Run exactly the one line matching your judgment.", 1, true) ~= nil,
    "the research verdict lines name the board commit and the session, nothing more: "
    .. research_body)
  f.worktree = nil
  f.head_sha = nil
  local cmds = full_commands()
  cmds.bootstrap_phrase = nil
  local _rbody, rowed = briefcontext.review(f, cmds)
  assert(table.concat(rowed, " ") == "<HEAD_SHA>",
    "a research review owes no worktree and no bootstrap plan: " .. table.concat(rowed, " "))
  f.product_root = nil
  local _pbody, powed = briefcontext.review(f, cmds)
  assert(table.concat(powed, " ") == "<HEAD_SHA> <PRODUCT_ROOT>",
    "but does owe the checkout it reproduces from: " .. table.concat(powed, " "))
  f.findings = nil
  local _dbody, dowed = briefcontext.review(f, cmds)
  assert(table.concat(dowed, " ") == "<HEAD_SHA> <WORKTREE> <BOOTSTRAP_PHRASE>",
    "a diff review owes both, in the rendered brief's own order: " .. table.concat(dowed, " "))
end

-- The round-context section renders from the same typed path as every
-- other template.
local function test_the_round_section_renders()
  local d: briefctx.Round = {
    round_number = "1",
    judged_head = "abc123",
    current_head = "def456",
    round_finding = "the guard was decoration",
  }
  local body = round.render(d)
  assert(body:find("Round 1 context", 1, true) ~= nil, body)
  assert(body:find("> the guard was decoration", 1, true) ~= nil, body)
end

-- A field no context record declares is a TYPE error in the generated
-- module, reported against the template's own line — the property the
-- whole build-time compile is bought for.
local function test_an_unknown_field_fails_the_generated_type_check()
  local src = "{{type Builder from _work.briefctx}}handle {{.handle}}\n"
  .. "title {{.ttile}}\n"
  local out, cerr = template.compile(src, "probe")
  assert(out ~= nil, "the template itself is well formed: " .. tostring(cerr))
  assert(out:find("-- probe:2", 1, true) ~= nil,
    "the generated read carries its template's own line: " .. out)
  local result = teal.check(out)
  assert(#result.errors > 0, "an undeclared field does not type check")
  local text = teal.format_issues(result.errors)
  assert(text:find("ttile", 1, true) ~= nil, "and the error names it: " .. text)
end
