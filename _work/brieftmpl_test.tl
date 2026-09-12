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
