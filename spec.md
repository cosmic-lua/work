## Evidence

See the parent outcome («AP77_4XCs») for the full evidence trail: gitboard's
`_work/gitworktree.tl` and `_work/brieftext*.tl` hardcode per-repo build
commands (bootstrap, gate, type-check, single-test) as `if`/`else` prose
or file-presence heuristics, one repo at a time. This item is the
foundation the others build on: a place gitboard resolves "how do I
build this repo" from, instead of matching on the repo's name.

The two repos in scope today already carry everything a resolver needs
without asking either repo to write anything new:
`cosmic-lua/cosmic`/`cosmic-lua/work` ship `bin/cosmic`, whose commands
are fixed by `_make`'s own convention (`--make ci`, `--make build`,
`--make test <file>`, `--check types <file>` are identical across every
cosmic-based project by design — see this project's own AGENTS.md,
"conventions, not declarations"); `cosmic-lua/cosmopolitan` already ships
a `Makefile`. A per-repo data-file manifest was the original shape
proposed here; it's dropped in favor of an interface (a fixed vocabulary
of `make` target names a non-cosmic repo implements) rather than a fact
(a value some format has to declare and gitboard has to keep in sync) —
cosmic's own history argues the same way for its own tree (D16: "the
`git describe` stamp went with the Makefile" when cosmic moved off one
towards `_make`'s convention-based system), and a repo that can run
`make gate` already answers the question without writing anything down.

`_work/product.tl` remains the closest existing precedent in this
codebase for "a small, documented module answering one repo-scoped
question" — though it answers a different question (which repo this
board tracks) than the one this item answers (how to build a given
repo).

## Change

Design and land the resolver:

1. `_work/repoprofile.tl` (new module): given a checkout path, resolve
   one of three outcomes, never throwing —
   - **`cosmic`**: `bin/cosmic` exists at the checkout root. Commands
     are fixed by convention, not probed: bootstrap
     `{"bin/cosmic","--make","fetch"}` then `{"bin/cosmic","--make","build"}`;
     gate `{"bin/cosmic","--make","ci"}`; check-file
     `{"bin/cosmic","--check","types",file}`; test-file
     `{"bin/cosmic","--make","test",file}`.
   - **`make`**: a `Makefile` exists and at least one of the four target
     names dry-runs successfully. Probe each of `bootstrap`, `gate`,
     `check-file`, `test-file` independently with `make -n <target>`
     (a dry run — never actually runs the target); a target whose dry
     run fails (`No rule to make target ...`) comes back absent for
     that field rather than failing the whole resolution — a repo may
     have no bootstrap step, the same as cosmic's own "or none." The
     two file-taking commands are built as `{"make","check-file","FILE="..file}`
     and `{"make","test-file","FILE="..file}`.
   - **absent**: neither applies — "unrecognized tree," exactly today's
     fallback.
2. The default base branch is a separate, unconditional resolution, not
   part of the kind above: `git symbolic-ref refs/remotes/origin/HEAD`
   against the checkout (via `child.run`, the same style
   `gitworktree.tl`'s existing `checkout_slug` already uses), parsed to
   a branch name, with a documented `""` result when the remote reports
   none (a shallow or single-branch clone) — callers decide their own
   fallback for `""`.
3. Every probe (`make -n`, `git symbolic-ref`) is best-effort: a
   `child.run` failure for any reason (no `make` on PATH, not a git
   checkout at all) folds into "absent"/`""`, never a thrown error or a
   refusal surfaced to the caller — resolution degrades, it never
   crashes.

Land the resolver tested against fixtures so the next two children have
something real to call.

Tests: a fixture checkout with `bin/cosmic` present, asserting the
`cosmic`-kind commands; a fixture checkout with a `Makefile` exposing
all four targets, asserting the `make`-kind commands (including the
`FILE=` substitution); a fixture `Makefile` missing one target (e.g. no
`bootstrap`), asserting that field comes back absent while the other
three resolve; a checkout with neither, asserting the absent/unrecognized
result; a checkout whose git remote reports a default branch, asserting
it resolves; a checkout whose remote reports none, asserting `""`.

## Non-goals

Not yet wiring `gitworktree.tl`/`brieftext*.tl` to USE this resolver —
that is the next two children, sequenced after this one lands (they'd
conflict with each other and with a still-moving resolver interface if
built concurrently). Not adding the real `bootstrap`/`gate`/`check-file`/
`test-file` targets to `cosmic-lua/cosmopolitan`'s own Makefile yet —
this item builds and tests the resolver against fixtures; wiring
cosmopolitan's actual Makefile is a small follow-on once the resolver's
shape is settled and the callers exist. Not inventing any new file
format or schema — the two things being detected (`bin/cosmic`'s
presence, a Makefile's target names) already exist as ordinary build
artifacts for other reasons; no repo writes anything new for this item
to read.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
