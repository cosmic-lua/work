- `3p/tl/tl_patch/integer.tl`: two entries, both gated behind
  `COSMIC_INTEGER_STRICT=1` read the way `cast.tl` reads its variable:
  1. assigning or passing a `number`-typed value where `integer` is
     declared is refused with `integer-strict: number is not integer`
     unless the operand's type is `integer` (integer literals and
     `//`, `&`, `|`, `~`, `<<`, `>>` results stay integer as tl already
     types them);
  2. `math.type(x) == "integer"` (and `~=` in the else arm) narrows a
     plain-variable `x` from `number` to `integer` inside the guarded
     block — the same fact mechanism `narrow-eq-nil` uses (`narrow.tl:130`).
- `docs/design/integer-strictness.md`: the Method command
  (`COSMIC_INTEGER_STRICT=1 xargs -a <(git ls-files '*.tl' | grep -v /testdata/) o/bin/cosmic --check types --include-dir . 2>&1 | grep -c 'integer-strict:'`),
  the count, and the refusals grouped by file with one line each on
  whether the site is a real `number` (needs a guard or a
  `math.tointeger`) or a tl declaration gap (an API that returns
  `number` for an integral value). Keep it under 200 lines.
- `_build/tl_patch_test.tl` (or the existing patch test the directory
  has — `git ls-files _build | grep -i patch`): one case each way for
  both entries.
- Follow-up items, filed not built: the upstream tl issue for the
  narrowing fact; one item per file group the census says is real.
- `bin/cosmic --make ci` ends `ci: PASS` with the rule OFF; the patch
  applies against the pinned tl or `--make fetch` refuses loudly.
