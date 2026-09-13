- **Removing `--examples` as a top-level flag.** The issue itself frames
  "whether the consolidated form is a breaking CLI change" as an open
  question needing its own decision; this slice answers it conservatively
  (no removal, no deprecation warning) so it ships as a pure internal
  de-duplication. Dropping `--examples` entirely — or aliasing it with a
  deprecation notice — is a separate, riskier follow-up that needs its own
  call (arguably a `docs/decisions/` entry, since D26 gates directional CLI
  surface changes) and is explicitly out of scope here.
- **`cosmic --make docs` / `_docs/`** (doc *publishing*, a different system
  with a similar name) is unaffected and untouched — the issue names the
  adjacency only to rule out confusing the two; this slice does not touch
  `_docs/`.
- **`--check-examples`** (`_cli/args.tl:108`, a distinct `--check` sub-verb
  that type-checks example files, unrelated to browsing them) is untouched.
- Command-parsing changes sit inside this project's pre-install boundary
  (`AGENTS.md`, "Build System"); this slice adds a new query *string* dispatch
  inside `cosmic.doc`, not a new flag or a changed flag arity, so it is not
  expected to need the release/pin staging that boundary's signature changes
  require — call this out explicitly in review if that reading is wrong.
