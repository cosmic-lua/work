- **No `cosmic/**` source changes.** The tree already satisfies the
  rule (Evidence), so a diff that edits a library site means the rule
  is wrong. Acceptance step 7 checks this directly. In particular
  `cosmic/check.tl` and `cosmic/rand.tl` are not annotated — their
  exemptions are module-level and already recorded.
- **No decision-record change.** D30, D23 and D22 are the contract;
  this enforces D30 and amends nothing. `docs/decisions/**` is not
  touched, and neither is `AGENTS.md`, whose bullet D30 already
  extended.
- **`assert-justify` and `cast-justify` do not change behaviour.** The
  only edit to `_cli/assert_lint.tl` is calling the moved predicate;
  its diagnostics, message text and rule name are frozen, which
  Acceptance step 3 checks by running that rule's own tests.
- **`is_justified` is not touched**, and no second justification
  marker is invented: `throws` and `exits` are D30's two, and the
  reader already takes the marker as an argument.
- **No new lint flag, no `--check lint` CLI change, no new rule
  beyond `throw-justify`**, and no widening of the rule to
  `error(`/`os.exit(` outside `cosmic/**` — the internal tree is not
  under D23 or D30 and this rule says nothing about it.
- **No other helper moves into `_tool/lint.tl`.** One predicate, for
  the one reason stated.
- **Frozen:** the `Diagnostic` record's fields; the
  `-- cast:` / `-- assert:` grammars and their lints; `tl.lex` usage;
  `_build/guides_test.tl`'s scope.
