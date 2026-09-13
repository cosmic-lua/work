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
