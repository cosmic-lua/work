In `_make/artifact.tl` (499 lines), `build()` (line 443):

1. Extract a testable checker:
   `verify_payload(path: string, expected: integer): string | nil` —
   open `path` with `cosmic.zip` (read mode), `list()` it, return an
   error string unless `main.lua` is present and `#entries ==
   expected`. Probed 2026-08-19 against a built cosmic: `zip.open` +
   `list()` reads an APE artifact's payload directly (554 entries,
   `main.lua` found), so the check needs nothing outside the box.
2. Call it between `embedc.write` (whose return `count` is the
   expected entry total) and `replace_if_changed`: on failure, remove
   `staged_out` and fail the build with a message naming the artifact,
   both counts, and the likely cause — another `--make` mutating this
   tree — so the operator learns the reason, not just the symptom.
3. Export `verify_payload` through the module record for the test.
4. **Tests** (`_make/artifact_test.tl`): build a small zip with
   `cosmic.zip` containing `main.lua` and one module → verifies at the
   right count, fails at the wrong count; one WITHOUT `main.lua` →
   fails naming it. No race simulation — the checker is pure and the
   race's product (a payload-light zip) is exactly what the fixtures
   construct.
