#!/usr/bin/env cosmic
-- `brief --out`: the filled body written to FILE round-trips
-- byte-for-byte against what a bare brief prints to stdout, for a
-- spec carrying exactly the characters a prompt channel that decodes
-- escapes corrupts — a backtick fence, a literal `\t`, a trailing
-- backslash — the albm_OBbo review brief's own evidence. Split from
-- `_work/brief_test.tl`, which sits against the file cap.

local brief = require("_work.brief")
local check = require("cosmic.check")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local gitspec = require("_work.gitspec")
local store = require("_work.store")

local init_state_repo = fixture.init_state_repo
local root_with_leaf = fixture.root_with_leaf

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"

--- A spec carrying exactly the characters a prompt channel that
--- decodes `\uXXXX`-style escapes turns into literal characters —
--- a backtick code fence, a literal `\t`, and a trailing backslash a
--- line-continuation reading would eat. A Teal long-bracket string,
--- so every backslash here is the two literal characters it looks
--- like, never an escape this file's own compiler resolves.
local TRICKY_SPEC < const > = [[
## Change
Map ` to ``` — one line ends in a tab escape: col1\tcol2, and this
one ends in a trailing backslash\
## Non-goals
Nothing else.
]]

--- File `id` with `TRICKY_SPEC` — `_work.fixture`'s own `give_spec`
--- is fixed to its own READY_SPEC, so this file carries its own.
--- @param s store.Store The store
--- @param id string The item id
local function give_tricky_spec(s: store.Store, id: string)
  local path = fs.join(tmpdir, "tricky-spec.md")
  assert(fs.write(path, TRICKY_SPEC))
  assert(gitspec.cmd_spec(s, id, path) == 0, "spec should be accepted")
end

--- Run brief.cmd_brief and capture exactly what it prints via
--- print() — the same swap-and-restore pattern `_work.brief_test`'s
--- own `brief_and_capture` uses, with `out` threaded through so the
--- same helper covers both the stdout and the `--out` path.
--- @param s store.Store The store
--- @param kind string The brief kind
--- @param id string The item id
--- @param out string | nil Passed through to cmd_brief's own `out`
--- @return integer cmd_brief's exit code
--- @return string Every print()'d line, newline-joined
local function brief_and_capture(s: store.Store, kind: string,
    id: string, out?: string): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(brief.cmd_brief, s, kind, id, out)
  _G.print = old_print
  if not ok then
    error(result, 0)
  end
  return result, table.concat(lines, "\n")
end

--- A bare brief prints the body, then its own verdict line as a
--- second, separate `print()` call — `brief_and_capture` joins every
--- call with "\n", so the body is everything before the LAST line;
--- the verdict line itself is always one line (`gate.verdict_line`
--- formats it in a single `print`).
--- @param full string Every printed line, newline-joined
--- @return string Everything but the final line
local function strip_verdict_line(full: string): string
  return (full:match("^(.*)\n[^\n]*$")) or full
end

-- `--out FILE` writes the same body a bare brief prints, byte for
-- byte: nothing between cosmic and the file does any decoding, so
-- the fence, the tab escape, and the trailing backslash all ride
-- exactly as the spec wrote them.
local function test_out_round_trips_byte_for_byte_against_stdout()
  local s = init_state_repo("brief-out")
  local _, leaf = root_with_leaf(s)
  give_tricky_spec(s, leaf)
  local scode, stdout_full = brief_and_capture(s, "builder", leaf)
  assert(scode == 0, "stdout brief: " .. stdout_full)
  local stdout_body = strip_verdict_line(stdout_full)
  local out_path = fs.join(tmpdir, "brief-out-body.md")
  local fcode, _fverdict = brief_and_capture(s, "builder", leaf, out_path)
  assert(fcode == 0, "brief --out should succeed")
  local file_body = check.must(fs.read(out_path))
  assert(file_body == stdout_body,
    ("--out must round-trip byte for byte against stdout's own body:\n"
      .. "stdout=%q\nfile=%q"):format(stdout_body, file_body))
  assert(file_body:find("```", 1, true) ~= nil,
    "the code fence rides verbatim: " .. file_body)
  assert(file_body:find("col1\\tcol2", 1, true) ~= nil,
    "the tab escape rides verbatim, never decoded: " .. file_body)
  assert(file_body:find("backslash\\\n", 1, true) ~= nil,
    "the trailing backslash rides verbatim: " .. file_body)
end

-- The `--out` verdict line names the path written to and the
-- placeholders still to fill; the body itself never reaches stdout.
local function test_out_verdict_names_the_path_not_the_body()
  local s = init_state_repo("brief-out-verdict")
  local _, leaf = root_with_leaf(s)
  give_tricky_spec(s, leaf)
  local out_path = fs.join(tmpdir, "brief-out-verdict.md")
  local code, verdict = brief_and_capture(s, "builder", leaf, out_path)
  assert(code == 0, verdict)
  assert(verdict:find(out_path, 1, true) ~= nil,
    "the verdict line names the path: " .. verdict)
  assert(verdict:find("read it whole, it is your brief verbatim", 1, true) ~= nil,
    "the verdict line carries doctrine's own instruction: " .. verdict)
  assert(verdict:find("```", 1, true) == nil,
    "the body's own fence never reaches the printed verdict: " .. verdict)
  assert(verdict:find("claim it as", 1, true) ~= nil,
    "the minted claim label still rides the verdict, same as a bare brief: "
    .. verdict)
end
