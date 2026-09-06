#!/usr/bin/env cosmic
-- Split out of `_work/brief_test.tl`, which sits at the file cap
-- (`AGENTS.md`'s 500-line ceiling) already: the review-template
-- selection this covers — `REVIEW_SCRIPT` for a mechanical diff,
-- `REVIEW` for anything bigger — is `_work.brief`'s, but its own
-- test fixture lives here instead.

local fixture = require("_work.fixture")
local brief = require("_work.brief")
local gh = require("_work.gh")
local review = require("_work.review")
local store = require("_work.store")
local verbs = require("_work.gitverbs")

local init_state_repo = fixture.init_state_repo
local give_spec = fixture.give_spec
local root_with_leaf = fixture.root_with_leaf

--- Run brief.cmd_brief and capture exactly what it prints via
--- print() — the same swap-and-restore pattern `_work/brief_test.tl`'s
--- own `brief_and_capture` uses.
--- @param s store.Store The store
--- @param id string The item id
--- @return integer cmd_brief's exit code
--- @return string Every print()'d line, newline-joined
local function brief_and_capture(s: store.Store, id: string): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(brief.cmd_brief, s, "review", id)
  _G.print = old_print
  if not ok then error(result, 0) end
  return result, table.concat(lines, "\n")
end

--- Stand a green, fixed-shape PR in for the duration of `f`: CI is
--- always green (the selection only runs once a review would
--- otherwise emit), and `files`/`additions`/`deletions` are exactly
--- what the case under test wants to probe.
--- @param files {string} The PR's changed file paths
--- @param additions integer
--- @param deletions integer
--- @param f function(): boolean The test body; returns true when done
local function with_diff_fixture(files: {string}, additions: integer,
    deletions: integer, f: function(): boolean)
  local real_head_checks, real_pull, real_checks, real_get_files
  = gh.head_checks, gh.pull, gh.checks, gh.get_files
  local sha = "d1ffbeef00d1ffbeef00d1ffbeef00d1ffbeef0"
  gh.head_checks = function(_s: store.Store, _pr: integer, _repo: string | nil):
    gh.HeadChecks | nil, string
    return {state = "green", head_sha = sha, runs = {}}, ""
  end
  gh.pull = function(_s: store.Store, number: integer, _repo: string | nil):
    review.Pull | nil, string
    return {number = number, draft = false, merged = false, body = "",
      head_sha = sha, base = "", state = "open", merge_sha = "",
      additions = additions, deletions = deletions}, ""
  end
  gh.checks = function(_s: store.Store, _sha: string, _repo: string | nil):
    {review.CheckRun} | nil, string
    return {}, ""
  end
  gh.get_files = function(_s: store.Store, _n: integer, _r: string | nil): {string} | nil, string
    return files, ""
  end
  local ok, err = pcall(f)
  gh.head_checks, gh.pull, gh.checks, gh.get_files
  = real_head_checks, real_pull, real_checks, real_get_files
  if not ok then error(err, 0) end
end

-- The selection rule is the spec's own, checked at both ends: a
-- 2-line pin diff (well under 20 changed lines, regardless of the
-- one file's own `.tl` extension) earns the numbered script; a
-- 200-line `.tl` diff outside `*_test.tl` keeps the full adversarial
-- `REVIEW`.
local function test_diff_shape_picks_the_review_template()
  for _, case in ipairs({
      {name = "pin", files = {"3p/cosmos/cosmos_pin.tl"}, additions = 1,
        deletions = 1, script = true},
      {name = "tl", files = {"cosmic/example.tl"}, additions = 150,
        deletions = 50, script = false},
    }) do
    local s = init_state_repo("brief-review-script-" .. case.name)
    local _, leaf = root_with_leaf(s)
    give_spec(s, leaf)
    assert(verbs.cmd_take(s, leaf, "session-a", 0, false, "") == 0)
    assert(verbs.cmd_take(s, leaf, "session-a", 13, false, "") == 0)
    with_diff_fixture(case.files, case.additions, case.deletions,
      function(): boolean
        local code, out = brief_and_capture(s, leaf)
        assert(code == 0, ("%s: a green diff still earns the brief: %s")
          :format(case.name, out))
        if case.script then
          assert(out:find("git show", 1, true) ~= nil,
            ("%s: a small diff selects the numbered script: %s")
            :format(case.name, out))
        else
          assert(out:find("fresh-context code reviewer", 1, true) ~= nil,
            ("%s: a big .tl diff keeps the adversarial REVIEW: %s")
            :format(case.name, out))
          assert(out:find("How to review — a numbered script", 1, true) == nil,
            ("%s: REVIEW never carries the script's own heading: %s")
            :format(case.name, out))
        end
        return true
      end)
  end
end
