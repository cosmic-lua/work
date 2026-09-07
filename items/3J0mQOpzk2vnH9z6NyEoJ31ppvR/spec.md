## Evidence

See the parent outcome («AP77_4XCs») for the full evidence trail: gitboard's
`_work/gitworktree.tl` and `_work/brieftext*.tl` hardcode per-repo build
commands (bootstrap, gate, type-check, single-test) as `if`/`else` prose
or file-presence heuristics, one repo at a time. This item is the
foundation the others build on: a place for a product repo to declare
its own mechanics, and a reader in `cosmic-lua/work` that resolves it.

`_work/product.tl` is the closest existing precedent in this codebase for
"a small, documented constant module answering one repo-scoped
question" — though it answers a different question (which repo this
board tracks) than the one this item answers (how to build a given
repo). `bin/cosmic.pin` is the closest precedent for "a tool reads a
small, plain, checked-in data file it never executes."

## Change

Design and land the manifest format and its reader:

1. A small, plain data file's shape (following this project's own
   convention — `cosmic.literal` is the house format elsewhere; a `.tl`
   record literal read the way `bin/cosmic.pin`'s two plain lines are
   read is the other local precedent) declaring, at minimum: the
   bootstrap command(s) for a fresh worktree (a list, or empty), the
   full-gate command, the type-check-one-file command (with a `<file>`
   substitution point), the run-one-test-file command (same), and the
   default base branch. Pick the concrete file name/location and
   literal shape as part of this item's own design work — cite the
   precedent chosen and why.
2. A reader in `cosmic-lua/work` (a new small module, e.g.
   `_work/repoprofile.tl`) that, given a checkout path, looks for the
   manifest at its declared location and returns the parsed fields, or
   a documented "no manifest" result when absent — never throws, never
   requires a manifest to exist (a repo gitboard has never seen degrades
   gracefully; see the parent's Non-goals).
3. `_work/gitworktree.tl`'s `bootstrap()` currently DETECTS a cosmic
   tree by `bin/cosmic`'s presence, then hardcodes its commands; a
   cosmopolitan tree by `third_party/lua`'s presence, with no commands.
   Leave the detection heuristics as this item's own concern to resolve
   (a manifest's mere presence may replace file-presence detection
   entirely, or file-presence may stay as how gitboard finds a checkout
   that has one) — but land the reader itself, tested against a fixture
   manifest, so the next two children have something real to call.

Tests: a fixture repo checkout carrying a manifest, asserting each field
parses; a checkout with no manifest, asserting the documented empty
result; a malformed manifest, asserting a refusal (never a crash) naming
the file and the parse problem.

## Non-goals

Not yet wiring `gitworktree.tl`/`brieftext*.tl` to USE this reader — that
is the next two children, sequenced after this one lands (they'd
conflict with each other and with a still-moving reader interface if
built concurrently). Not adding a manifest to `cosmic-lua/cosmic` or
`cosmic-lua/cosmopolitan` yet — this item builds the reader against a
test fixture; wiring an actual product repo's own manifest is a small
follow-on once the reader's shape is settled and the callers exist.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
