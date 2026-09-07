## Change

Fold `cast-justify` (`_cli/lint.tl`'s comment-presence check) and the
cast-kind classification (`_build/casts_test.tl`, a separate whole-tree
`_test.tl`) into one `--check lint` rule: a cast passes when it
structurally matches an allowlisted kind (via `cosmic.ast`, no comment
needed) OR carries a `-- cast: <reason>` justification comment
(today's path); otherwise it fails. Depends on the sibling item
(drop the ceiling) landing first — this item deletes the file that
item leaves stripped down.

**Why this can be a per-file lint now.** With the ceiling and
zero-site checks gone, classifying one cast needs only that cast's own
AST node plus the static `KINDS` table (`_build/casts_kinds.tl`'s
`pattern`/`where`/`explicit` fields) — no cross-file aggregation
survives. `_build/casts_test.tl`'s own `kind_matches`/`is_in_scope`
(lines 66-73, 142-154) already operate on one `Site` at a time; only
`scan` (lines 95-135) walks the whole tree, and it does so only to
produce the flat list `test_every_cast_site_matches_exactly_one_kind`
iterates — the same coverage `--check lint`/`--make lint` already get
for free by running `lint_file` over every file the project walk
hands it.

**`_cli/lint.tl`**: add `local ast = require("cosmic.ast")` and `local
teal = require("cosmic.teal")` to the requires block (lines 17-28).
Port from `_build/casts_test.tl`, verbatim except for the changes
named below: the `Site`/`Compiled` records (lines 42-54), `ANY_CAST`
(line 59), `is_in_scope` (lines 66-73), `compile_kinds` (lines 78-88),
`kind_matches` (lines 137-154). Do not port `scan`, `near_matches`,
`matching_kinds`, or the three `test_*` functions — this rule checks
one file's cast sites, not the whole tree's, and reports pass/fail
per site rather than aggregating a kind-name list.

Add a loader, cached at module scope since the path is fixed and the
same for every file linted in one run:

```
local CASTS_KINDS_PATH <const> = "_build/casts_kinds.tl"
local kinds_loaded = false
local compiled_kinds: {Compiled} = {}

local function loaded_kinds(): {Compiled}
  if kinds_loaded then
    return compiled_kinds
  end
  kinds_loaded = true
  if fs.is_file(CASTS_KINDS_PATH) then
    local code = teal.compile_cached(CASTS_KINDS_PATH)
    if code then
      local chunk = load(code)
      if chunk then
        local ok, mod = pcall(chunk)
        if ok and mod and mod.KINDS then
          compiled_kinds = compile_kinds(mod.KINDS)
        end
      end
    end
  end
  return compiled_kinds
end
```

This never throws: a missing file, a compile failure, or a load
failure all fall through to the empty table, which makes every cast
in that run fall back to the comment path — the same behavior as
today for every project that has no `_build/casts_kinds.tl` (i.e.
every project except this one). `fs.is_file` is a cwd-relative check,
consistent with how `lint_file`'s own `path` argument is already
cwd-relative (it never resolves an absolute project root either).

Rewrite `check_cast_justification` (lines 63-83) to parse the file
with `cosmic.ast` instead of scanning lexer tokens for the bare `as`
keyword, and to check each cast site against `loaded_kinds()` before
falling back to `style.is_justified`:

```
local function check_cast_justification(file: string, content: string,
    lines: {string}): {Diagnostic}
  local diagnostics: {Diagnostic} = {}
  local parsed = ast.parse(content, file)
  if not parsed then
    return diagnostics
  end
  local compiled = loaded_kinds()
  for _, hit in ipairs(ast.find_all(parsed.node, ANY_CAST)) do
    local y = ast.span_start(hit.node)
    local site: Site = {path = file, y = y,
      text = str.trim(lines[y] or ""), node = hit.node}
    local allowlisted = false
    for _, c in ipairs(compiled) do
      if kind_matches(site, c) then
        allowlisted = true
        break
      end
    end
    if not allowlisted and not style.is_justified(lines, y, "cast") then
      diagnostics[#diagnostics + 1] = {
        file = file, line = y, col = 1, rule = "cast-justify",
        message = string.format(
          "%s:%d: `as` cast without justification: prefer `is` narrowing"
          .. " or check.must (see `cosmic --docs guide.checking`); a"
          .. " deliberate cast either matches an allowlisted kind in"
          .. " `_build/casts_kinds.tl` or takes a trailing `-- cast:"
          .. " <reason>` (or one on the line above)",
          file, y),
      }
    end
  end
  return diagnostics
end
```

`str` (`require("cosmic.string")`, for `.trim`) joins the requires
block alongside `ast`/`teal`. `cast_lines` (lines 40-54, the lexer-only
line-number finder) is unused by this rewrite; check
`grep -rn "cast_lines" --include='*.tl' .` for other callers before
deciding whether to keep it as a still-exported utility or delete it
— if nothing outside `_cli/lint.tl` and its own `LintModule` record/
export table calls it, delete it and its two entries in
`LintModule`/`M` (lines 396, 416).

Pass if a cast matches ANY allowlisted kind — do not port
`test_every_cast_site_matches_exactly_one_kind`'s "matches exactly
one, not two" strictness. A site matching two kinds is not a failure
mode this rule reports; the ceiling/exhaustiveness discipline that
made that distinction worth catching is what the sibling item already
removed.

**Delete `_build/casts_test.tl`** in full — its classification logic
now lives in `_cli/lint.tl`, and `--check lint`/`--make lint` walking
every file already gives equivalent whole-tree coverage without a
separate `_test.tl`. Do not delete `_build/casts.tl` (the `TREES`
list) — `_build/size.tl` also requires it (`grep -rln
'require("_build.casts")'` → `_build/size.tl` and `_build/casts_test.tl`
today; only the latter goes away).

**`docs/design/casts.md`**: in the Method section, replace the
`_build/casts_test.tl` reference (the sentence naming it as what
checks the allowlist "against a fresh `cosmic.ast` walk of the tree on
every run") with a reference to `--check lint`'s `cast-justify` rule
in `_cli/lint.tl`, since that is now what runs the check, per-file, as
part of every `--make ci`/`--make lint` invocation rather than as its
own test target.

**`_cli/lint_test.tl`**: add a test asserting the allowlist path passes
without a comment (parse a fixture whose cast matches one of
`_build/casts_kinds.tl`'s real patterns, e.g. a `userdata boundary`
site scoped to `cosmic/fs/`) and a test asserting an unmatched,
uncommented cast still fails exactly as `test_the_pure_checks_come_from_style`
(lines 200-207) already establishes belongs to `_cli.lint`.

## Non-goals

Does not generalize the allowlist into a documented per-project
convention — `_build/casts_kinds.tl` stays this repo's own data, read
opportunistically off disk by a generic rule that no-ops when the file
is absent. Does not change `cosmic.ast`'s pattern grammar to
distinguish same-rendered-type collisions (the `explicit` list stays
the mechanism for those) — investigated and rejected in review as
disproportionate machinery for ~16 stable sites.

## Acceptance

`bin/cosmic --make ci` ends `ci: PASS`. A cast under `cosmic/fs/` that
matches the `userdata boundary` pattern and carries NO `-- cast:`
comment passes `--check lint`; a cast anywhere else that matches no
kind and carries no comment still fails it with the reworded
`cast-justify` message.
