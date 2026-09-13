#!/usr/bin/env cosmic
-- The dispatcher's id resolution: every id-taking argument position —
-- not only the first — accepts a rendered handle, and a handle that
-- names nothing is refused the same way a bad prefix is. The verbs
-- themselves are exercised with resolved ids elsewhere
-- (`_work/gitrank_test.tl`, `_work/gitgraph_test.tl`); this is the
-- dispatch layer in `_work/gitboard.tl` that resolves what a session
-- typed before a verb ever sees it.

local cache = require("_work.cache")
local cachedb = require("_work.cachedb")
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gate = require("_work.gitgate")
local gitboard = require("_work.gitboard")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local specmod = require("_work.spec")
local refs = require("_work.refs")
local store = require("_work.store")
local storewrite = require("_work.storewrite")
local tail = require("_work.tail")

local init_state_repo = fixture.init_state_repo
local file_item = fixture.file_item
local tmpdir = fixture.tmpdir
local READY_SPEC = fixture.READY_SPEC

--- Run gitboard.main(...) and capture exactly what it prints via
--- print() -- the same swap-and-restore pattern _eval/score_test.tl
--- uses to pin a CLI's exact console output, without a real subprocess.
--- @param ... string Arguments to pass to gitboard.main, as on argv
--- @return integer gitboard.main's exit code
--- @return string Every print()'d line, newline-joined, no trailing newline
local function gitboard_and_capture(...: string): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(gitboard.main, ...)
  _G.print = old_print
  if not ok then
    error(result, 0)
  end
  return result, table.concat(lines, "\n")
end

--- Run `show ID --raw` with stdout redirected to a file, preserving every
--- byte for an assertion instead of routing it through `print()`.
local function gitboard_raw_capture(s: store.Store, id: string): integer, string
  local path = fs.join(tmpdir, "raw-show-output")
  local real_stdout = io.stdout
  local output = assert(io.open(path, "w"))
  io.stdout = output
  local ok, result = pcall(gitboard.main, "show", id, "--raw",
    "--dir", s.root)
  output:flush()
  output:close()
  io.stdout = real_stdout
  if not ok then
    error(result, 0)
  end
  return result, assert(fs.read(path))
end

-- Raw output is exactly what the two blobs render to, including their
-- unusual-but-valid content. It emits no verdict, header, history, or
-- synthetic newline, and an item with no prose at all prints nothing.
local function test_show_raw_round_trips_the_sidecar_byte_exactly()
  local s = init_state_repo("show-raw-byte-exact")
  local changes = {
    "line with a trailing newline\n",
    "line without a trailing newline",
    "",
    "literal ${template-looking} text\n",
  }
  for n, change in ipairs(changes) do
    local id = file_item(s, "raw sidecar " .. tostring(n), "")
    local it = check.must(store.load(s, id))
    local prose: itemtree.Spec = {change = change, non_goals = ""}
    assert(storewrite.save(s, it, "raw fixture", prose))
    fixture.caller_publish(s)
    local code, output = gitboard_raw_capture(s, id)
    assert(code == 0, "raw show should succeed: " .. output)
    assert(output == specmod.document(prose),
      "raw show must render blob " .. tostring(n) .. " exactly: " .. output)
  end
end

-- The CAS refusal gives a caller the same raw command that produces a
-- reusable base file, rather than the human report that adds formatting.
local function test_stale_spec_refusal_names_the_raw_show_command()
  local base = fs.join(tmpdir, "stale-raw-show-base")
  assert(fs.write(base, "## Change\n\nold\n"))
  local msg = check.must(gate.base_refusal(
      {change = "current\n", non_goals = ""}, base, "12345678"))
  assert(msg:find("`gitboard show 12345678 --raw`", 1, true) ~= nil,
    "the refusal should name byte-exact output: " .. msg)
  assert(msg:find("`gitboard show 12345678`", 1, true) == nil,
    "the refusal should not suggest the formatted report: " .. msg)
end

-- The command's own byte stream is a usable CAS base: an unchanged write
-- accepts it, an intervening one-byte edit makes that same base stale, and
-- both refusal forms point back to the raw producer.
local function test_raw_show_output_round_trips_through_spec_base_cas()
  local s = init_state_repo("show-raw-spec-cas")
  local id = file_item(s, "raw CAS item", "")
  local original = "## Change\n\noriginal\n"
  local it = check.must(store.load(s, id))
  assert(storewrite.save(s, it, "raw CAS fixture",
      {change = "original\n", non_goals = ""}))
  fixture.caller_publish(s)

  local code, base_text = gitboard_raw_capture(s, id)
  assert(code == 0 and base_text == original, "raw output is the base text")
  local base = fs.join(tmpdir, "raw-spec-cas-base")
  local same = fs.join(tmpdir, "raw-spec-cas-same")
  local intervening = fs.join(tmpdir, "raw-spec-cas-intervening")
  local edit = fs.join(tmpdir, "raw-spec-cas-edit")
  assert(fs.write(base, base_text))
  assert(fs.write(same, base_text))
  assert(gitboard.main("spec", id, same, "--base", base, "--dir", s.root) == 0,
    "the raw base accepts an unchanged spec write")
  assert(fs.write(intervening, "## Change\n\noriginaL\n"))
  assert(gitboard.main("spec", id, intervening, "--base", base,
      "--dir", s.root) == 0, "the raw base permits the intervening write")
  assert(fs.write(edit, "## Change\n\nmy edit\n"))
  local stale_code, stale_output = gitboard_and_capture("spec", id, edit,
    "--base", base, "--dir", s.root)
  assert(stale_code ~= 0, "the one-byte intervening change makes base stale")
  assert(stale_output:find("`gitboard show " .. id:sub(1, 8)
      .. " --raw`", 1, true) ~= nil,
    "stale refusal names the raw producer: " .. stale_output)
  local no_base_code, no_base_output = gitboard_and_capture("spec", id, edit,
    "--dir", s.root)
  assert(no_base_code ~= 0, "an existing spec still requires a base")
  assert(no_base_output:find("`gitboard show " .. id:sub(1, 8)
      .. " --raw`", 1, true) ~= nil,
    "no-base refusal names the raw producer: " .. no_base_output)
end

-- `attach`'s PARENT slot: a handle-form second argument resolves the
-- same as a prefix would, so a session pasting a handle from `show`
-- output can attach with it directly.
local function test_attach_resolves_a_handle_form_parent()
  local s = init_state_repo("attach-handle")
  local root = file_item(s, "an outcome", "")
  local leaf = file_item(s, "a workable slice", "")
  assert(gitboard.main("attach", leaf, tail.handle(root), "--dir", s.root) == 0,
    "a handle-form parent should resolve")
  local it = check.must(store.load(s, leaf))
  assert(it.parent == root, "and the attach actually landed")
end

-- A handle naming nothing is refused cleanly in a secondary slot too
-- — no crash, just the same "no item matches" store gives arg 1.
local function test_secondary_slot_refuses_a_handle_that_matches_nothing()
  local s = init_state_repo("attach-handle-miss")
  local child = file_item(s, "the item to place", "")
  local goal = file_item(s, "an outcome", "")
  local before_parent = check.must(store.load(s, child)).parent
  assert(gitboard.main("attach", child, "«ZZZZ_ZZZZ»", "--dir", s.root) ~= 0,
    "a handle matching nothing is refused")
  local unmoved = check.must(store.load(s, child))
  assert(unmoved.parent == before_parent, "and nothing was recorded")
  assert(gitboard.main("attach", child, goal, "--dir", s.root) == 0,
    "the store is still writable after the refusal")
end

-- `gitboard help` names the two id forms a session actually meets:
-- the handle every render leads with, and the branch prefix that is a
-- DIFFERENT string from it -- the confusion this item exists to close.
local function test_help_documents_the_id_forms()
  local code, printed = gitboard_and_capture("help")
  assert(code == 0, "help should exit 0, got " .. code)
  assert(printed:find("KSUIDs", 1, true),
    "help should say ids are KSUIDs\ngot: " .. printed)
  assert(printed:find("last 8", 1, true),
    "help should name the handle as the id's last 8 characters\ngot: " .. printed)
  assert(printed:find("«d0x1_37YJ»", 1, true),
    "help should carry the worked handle example\ngot: " .. printed)
  assert(printed:find("bare or wrapped", 1, true),
    "help should say a handle is accepted bare or wrapped\ngot: " .. printed)
  assert(printed:find("unambiguous prefix", 1, true),
    "help should say an unambiguous prefix also works\ngot: " .. printed)
  assert(printed:find("work/<handle>/<claim>", 1, true),
    "help should name the per-claim work branch\ngot: " .. printed)
  assert(printed:find("expired attempts never collide", 1, true),
    "help should explain why work branches include the claim\ngot: " .. printed)
end

-- The eleven verbs that only stage a mutation for `publish` — ten
-- through `commit_and_publish`, and `log --add` through its own
-- stream — say so in their own help, naming the follow-up that
-- actually pushes; `claim` already carries --execute and its own
-- authority wording, so the constant must not be sprayed onto it too.
local function test_help_names_the_prepare_only_verbs()
  for _, verb in ipairs({"new", "attach", "rank", "set", "spec", "depend",
      "undepend", "take", "verdict", "done", "log"}) do
    local code, printed = gitboard_and_capture("help", verb)
    assert(code == 0, ("help %s should exit 0, got %d"):format(verb, code))
    assert(printed:find("only PREPARES", 1, true) ~= nil,
      ("help %s should say it only PREPARES\ngot: %s"):format(verb, printed))
    -- The constant wraps "gitboard publish" and "--execute" onto
    -- separate rendered lines, so the two follow-ups are checked
    -- apart rather than as one joined phrase.
    assert(printed:find("gitboard publish", 1, true) ~= nil,
      ("help %s should name gitboard publish\ngot: %s"):format(verb, printed))
    assert(printed:find("gitboard refresh --execute", 1, true) ~= nil,
      ("help %s should name gitboard refresh --execute\ngot: %s")
      :format(verb, printed))
  end
  local claim_code, claim_printed = gitboard_and_capture("help", "claim")
  assert(claim_code == 0, "help claim should exit 0, got " .. claim_code)
  assert(claim_printed:find("only PREPARES", 1, true) == nil,
    "help claim should not carry the prepare-only constant\ngot: " .. claim_printed)
end

-- `resolve_id`'s tail (handle) branch leases the id it resolves to
-- from its own `for-each-ref` glob's matched row, the same one-shot
-- ticket a prefix match leaves for `load` — so `show <handle>` never
-- repeats a for-each-ref for the id it already found.
local function test_show_with_a_handle_never_repeats_loads_for_each_ref()
  local s = init_state_repo("show-handle-lease")
  local id = file_item(s, "an item", "")
  -- `new`'s own pre-mint duplicate check already warms `o/board.db` as
  -- a side effect (`_work.cachequery.similar_lines`); wipe it so this
  -- resolves through the glob this test is actually about, not the
  -- cache-first path — which cannot carry a lease at all (no ref/sha
  -- column exists to carry it) and is covered on its own terms by
  -- `test_a_handle_absent_from_the_cache_resolves_through_the_glob`.
  cachedb.wipe(s.root)
  local exact_pattern = {"refs/heads/items/" .. id, "refs/heads/ended/" .. id}

  local exact_calls = 0
  local real_for_each_ref = refs.for_each_ref
  refs.for_each_ref = function(root: string, patterns: {string}):
    {refs.RefEntry} | nil, string
    if #patterns == 2 and patterns[1] == exact_pattern[1]
    and patterns[2] == exact_pattern[2] then
      exact_calls = exact_calls + 1
    end
    return real_for_each_ref(root, patterns)
  end
  local ok, code = pcall(gitboard_and_capture, "show", tail.handle(id), "--dir", s.root)
  refs.for_each_ref = real_for_each_ref
  if not ok then
    error(code, 0)
  end
  assert(code == 0, "show <handle> should succeed")
  assert(exact_calls == 0, "a handle's own load must not repeat the "
    .. "exact-ref for-each-ref a bare id's load would run: " .. exact_calls)
end

-- Resolving a handle must never fall back to a whole-board load:
-- `spec` is a verb whose own body never calls `store.list` either, so
-- a stub that fails the test on any call proves resolution itself
-- reaches for it no more than the verb it feeds does (zero times).
local function test_handle_resolution_never_loads_the_whole_board()
  local s = init_state_repo("handle-no-list")
  local id = file_item(s, "an item", "")
  local spec_path = fs.join(tmpdir, "handle-no-list-spec.md")
  assert(fs.write(spec_path, READY_SPEC))
  local real_list = store.list
  store.list = function(_s: store.Store): {item.Item} | nil, string
    error("store.list must not run to resolve a handle", 0)
  end
  local ok, code = pcall(gitboard.main, "spec", tail.handle(id), spec_path, "--dir", s.root)
  store.list = real_list
  if not ok then
    error(code, 0)
  end
  assert(code == 0, "spec ID FILE should resolve a handle without a whole-board load")
end

-- A handle's case does not have to match what `for-each-ref`'s own
-- fnmatch would require exactly — retyping tolerance costs one MORE
-- for-each-ref (the whole-namespace, names-only fallback), never a
-- whole-board load.
local function test_a_mixed_case_handle_resolves_through_the_fallback()
  local s = init_state_repo("handle-case-fold")
  local id = file_item(s, "an item", "")
  -- The cache's own lookup already folds case (`lower(id) LIKE
  -- '%'||lower(?)`), so it would answer this one directly; wipe the
  -- cache `new`'s pre-mint check warmed so this exercises the GLOB's
  -- own case-fold fallback instead.
  cachedb.wipe(s.root)
  local flipped = tail.bare(id):gsub("%a", function(c: string): string
      if c:match("%u") then
        return c:lower()
      end
      return c:upper()
    end)
  local fallback_pattern = {"refs/heads/items/*", "refs/heads/ended/*"}
  local fallback_calls = 0
  local real_for_each_ref = refs.for_each_ref
  refs.for_each_ref = function(root: string, patterns: {string}):
    {refs.RefEntry} | nil, string
    if #patterns == 2 and patterns[1] == fallback_pattern[1]
    and patterns[2] == fallback_pattern[2] then
      fallback_calls = fallback_calls + 1
    end
    return real_for_each_ref(root, patterns)
  end
  local ok, code = pcall(gitboard.main, "show", "«" .. flipped .. "»", "--dir", s.root)
  refs.for_each_ref = real_for_each_ref
  if not ok then
    error(code, 0)
  end
  assert(code == 0, "a mixed-case handle should resolve through the fallback")
  assert(fallback_calls == 1,
    "expected exactly one fallback for-each-ref call, got " .. fallback_calls)
end

-- The cache only helps when it already carries the id: an item newer
-- than the file — a fetch this checkout has not caught up to, say —
-- still resolves, by falling through to the glob.
local function test_a_handle_absent_from_the_cache_resolves_through_the_glob()
  local s = init_state_repo("handle-cache-miss")
  check.must(cache.close(check.must(cache.open(s.root)))) -- primes o/board.db
  local id = file_item(s, "an item filed after the cache existed", "")
  local db = check.must(cachedb.open_conn(cachedb.path_of(s.root)))
  -- `events.item` REFERENCES `items(id)`; the filing above already gave
  -- this id one row there, so it goes first or the plain `items` delete
  -- below trips that foreign key.
  assert(db:exec("DELETE FROM events WHERE item = ?", {id}))
  assert(db:exec("DELETE FROM items WHERE id = ?", {id}))
  check.must(db:close())
  assert(gitboard.main("show", tail.handle(id), "--dir", s.root) == 0,
    "a handle absent from the cache should still resolve through the glob")
end

-- Bare `show --todo N` for a valid N parses clean and succeeds; the
-- rendering itself (row counts, the trailer) is `_work/gitview_test.tl`'s.
local function test_show_accepts_a_valid_todo_count()
  local s = init_state_repo("todo-flag-valid")
  local code, printed = gitboard_and_capture("show", "--todo", "3", "--dir", s.root)
  assert(code == 0, "a valid --todo should succeed: " .. printed)
end

-- Anything that is not a non-negative integer is a usage refusal on
-- the verdict line, not a crash or a silent default.
local function test_show_refuses_an_invalid_todo_count()
  local s = init_state_repo("todo-flag-invalid")
  for _, bad in ipairs({"abc", "-1", "2.5"}) do
    local code, printed = gitboard_and_capture("show", "--todo", bad, "--dir", s.root)
    assert(code ~= 0, ("--todo %s should be refused, got exit 0"):format(bad))
    assert(printed:find("--todo wants a non-negative integer", 1, true) ~= nil,
      ("the verdict line should name the refusal for --todo %s: %s")
      :format(bad, printed))
  end
end

-- `--todo` only shapes the board-wide render; `show ID` prints the
-- same thing with or without it.
local function test_show_id_ignores_the_todo_flag()
  local s = init_state_repo("todo-flag-no-effect-on-id")
  local id = file_item(s, "an item", "")
  local plain_code, plain_printed = gitboard_and_capture("show", id, "--dir", s.root)
  local flagged_code, flagged_printed = gitboard_and_capture("show", id, "--todo", "0",
    "--dir", s.root)
  assert(plain_code == 0 and flagged_code == 0, "show ID should succeed either way")
  assert(plain_printed == flagged_printed,
    "show ID's output should be unchanged by --todo:\n" .. plain_printed
    .. "\n---\n" .. flagged_printed)
end

-- `depend`'s ON slot is the second id-taking argument position, so it
-- resolves a rendered handle the same way `attach`'s PARENT does, and
-- the dispatch reaches the verb body with two full ids.
local function test_depend_resolves_a_handle_form_blocker()
  local s = init_state_repo("depend-handle")
  local root = file_item(s, "an outcome", "")
  local waiter = file_item(s, "the waiter", root)
  local blocker = file_item(s, "the blocker", root)
  assert(gitboard.main("depend", tail.handle(waiter), tail.handle(blocker),
      "--dir", s.root) == 0, "both slots should accept a handle")
  local it = check.must(store.load(s, waiter))
  assert(#(it.depends_on or {}) == 1 and it.depends_on[1] == blocker,
    "and the edge actually landed: " .. table.concat(it.depends_on or {}, ","))
  -- `undepend` rides the same branch and the same resolution.
  assert(gitboard.main("undepend", tail.handle(waiter), tail.handle(blocker),
      "--dir", s.root) == 0, "undepend takes the same two slots")
  assert(#(check.must(store.load(s, waiter)).depends_on or {}) == 0,
    "and withdrew it")
end

-- A handle in the ON slot that matches nothing is refused before the
-- verb body sees it, the same way a bad PARENT is.
local function test_depends_second_slot_refuses_an_unknown_handle()
  local s = init_state_repo("depend-handle-miss")
  local root = file_item(s, "an outcome", "")
  local waiter = file_item(s, "the waiter", root)
  assert(gitboard.main("depend", waiter, "«ZZZZ_ZZZZ»", "--dir", s.root) ~= 0,
    "a handle naming nothing in the ON slot is refused")
  assert(#(check.must(store.load(s, waiter)).depends_on or {}) == 0,
    "and nothing was written")
end

-- `set`'s two list flags are declared repeatable, so each occurrence is
-- one entry and the whole list reaches `cmd_set` — the same shape
-- `worktree --ref` already has.
local function test_set_collects_each_declared_list_flag_occurrence()
  local s = init_state_repo("set-lists-dispatch")
  local root = file_item(s, "an outcome", "")
  local leaf = file_item(s, "a slice", root)
  assert(gitboard.main("set", leaf, "--touches", "_work/a.tl",
      "--touches", "_work/b.tl", "--access", "cosmic-lua/cosmic",
      "--dir", s.root) == 0, "both flags should parse")
  local it = check.must(store.load(s, leaf))
  assert(#it.touches == 2 and it.touches[2] == "_work/b.tl",
    "each --touches is one entry: " .. table.concat(it.touches, " "))
  assert(#it.access == 1 and it.access[1] == "cosmic-lua/cosmic",
    "and --access the same: " .. table.concat(it.access, " "))
end
