## Evidence

Measured 2026-08-28 against `origin/main` `40776231`.

`docs/guides/lint.md:3-6` promises:

> `cosmic --make lint` (and its per-file form `cosmic --check lint <file>`)
> runs the style gate. every rule it can fire is enumerated here, with the
> failure it produces and the fix — so the first time you meet a rule is
> not the moment you have to reverse-engineer it.

The gate can fire 15 rules; the guide enumerates 13.

    grep -rhon 'rule = "[a-z-]*"' _cli/*.tl _tool/*.tl | sed 's/.*rule = //' \
      | sort -u | wc -l                        # 13
    grep -n 'unjustified(file, t, "' _cli/throw_lint.tl   # throw-justify, exit-justify
    grep -c '^## ' docs/guides/lint.md         # 13, of which 12 are rule sections
                                               # ("throw-justify and exit-justify"
                                               #  covers two, and one section is
                                               #  "running one rule's worth of output")

Undocumented: `doc-citation` and `reads-declaration`. `3IYPq8Sx` adds the
`## doc-citation` section, which leaves `reads-declaration` — the rule
`3I1RuEqx` introduced, which flags a test that reads the tree without a
`--- reads:` declaration. A session meeting it gets exactly the experience
the guide's own sentence promises it will not.

The guide ships in the binary (`cosmic --docs guide.lint`), so the false
sentence is delivered by the tool.

Re-measured 2026-09-05 against `origin/main`: `3IYPq8Sx` has landed —
`grep -c '^## ' docs/guides/lint.md` is now 14 (`## doc-citation` added at
`docs/guides/lint.md:348`) and `wc -l docs/guides/lint.md` is 419, 81
lines under the 500-line cap. `reads-declaration` is still the one gap
(`grep -c '^## reads-declaration' docs/guides/lint.md` is 0).

## Change

Insert a new `## reads-declaration` section in `docs/guides/lint.md`
between the end of `## doc-citation` (line 408, "...has not declared
anything.") and `## running one rule's worth of output` (line 410) — the
blank line at 409 separates them. Match the shape of the shorter existing
sections (`## nil-declaration`, `## return-assert`): a short prose
paragraph, a fenced example of the diagnostic, the fix, and the rule's
exact scope. Content, in order:

1. What the rule checks and why: a `*_test.tl` file that calls
   `fs.glob()` without a `--- reads:` header — `_make/imports.tl`'s
   dependency scan is static and can't see what the glob finds at
   runtime, so an undeclared call gets a cached PASS that outlives the
   tree it was supposed to re-check (`_cli/reads_lint.tl:1-9`).
2. A fenced example pairing the trigger with the exact diagnostic text,
   measured by running the built binary against a two-line fixture
   (`local fs = require("cosmic.fs")` /
   `local found = fs.glob("cosmic", "*.tl")`):

   ```
   o/bin/cosmic --check lint /tmp/lintcheck/some_test.tl
   /tmp/lintcheck/some_test.tl:2:15: reads-declaration: /tmp/lintcheck/some_test.tl:2: fs.glob() enumerates files with no '--- reads:' declaration; a static import scan can't see what it finds at runtime, so this test's cached PASS never re-runs when those files change — add '--- reads: <dir>' naming what the glob covers (see _make/imports.tl)
   ```

3. The fix — the header the message itself names, confirmed clearing the
   diagnostic (`o/bin/cosmic --check lint` on the same fixture with the
   header prepended: `Style check passed`):

   ```teal
   --- reads: cosmic
   local fs = require("cosmic.fs")
   local found = fs.glob("cosmic", "*.tl")
   ```

4. Scope, from `_cli/reads_lint.tl:29-33`'s own doc comment: the trigger
   is `fs.glob` only — `fs.find`, `fs.find_iter`, `fs.find_info`,
   `fs.visit` and a computed `require` target are each a wider, unaudited
   trigger and are follow-up work, not this rule's job. The rule applies
   to `*_test.tl` files only.

Non-goals: the `_build/` ratchet idea in the Evidence above (asserting
every rule name in `_cli/*.tl`/`_tool/*.tl` has a matching `## <rule>`
heading) is a separate, independent change — file it as its own item if
it clears the bar, don't fold it into this doc slice.

## Acceptance

- `docs/guides/lint.md` gains one `## reads-declaration` section between
  `## doc-citation` and `## running one rule's worth of output`, in the
  shape above.
- `wc -l docs/guides/lint.md` stays at or under 500 (measured before this
  change: 419; the new section is well under the 81-line headroom).
- `o/bin/cosmic --check lint docs/guides/lint.md` still passes (the
  `doc-citation` rule has no fenced or inline `path:line` citations to
  check in the new prose — none are added).
- `grep -c '^## ' docs/guides/lint.md` is 15, and every rule name
  `_cli/*.tl`/`_tool/*.tl` can emit now has a matching heading.
