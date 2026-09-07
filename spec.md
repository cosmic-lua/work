## Evidence

gitboard's own generic workflow (claim, worktree, brief, take, verdict) is
meant to run against more than one product repo — this session alone
worked `cosmic-lua/cosmic`, `cosmic-lua/work` (its own board repo), and
`_work/gitworktree.tl` already names `cosmic-lua/cosmopolitan` as a third
recognized tree. But the MECHANICS of a given repo — what command
bootstraps a fresh worktree, what command runs its gate, what command
type-checks or runs one test file, what its default base branch is, what
file-length convention it enforces — are hardcoded directly into
gitboard's own shared, generic templates and functions, one repo at a
time, as `if`/`else` prose or file-presence heuristics:

- `_work/gitworktree.tl:121-125` (`default_base`): `repo:find("cosmopolitan", ...)`
  → `"master"`, else `"main"` — a repo-name string match.
- `_work/gitworktree.tl:137-151` (`bootstrap`): presence of `bin/cosmic` at
  the worktree root → run `{"bin/cosmic", "--make", "fetch"}` then
  `{"bin/cosmic", "--make", "build"}`; presence of `third_party/lua` →
  nothing; else → nothing, tree unrecognized.
- `_work/brieftext.tl:73-74` (the `BUILDER` template, used for every
  build regardless of target repo): `` `bin/cosmic --make ci` for cosmic;
  `make -j$(nproc) o//tool/lua/test` for cosmopolitan `` — the gate
  command enumerated inline, by repo name, in shared prose.
- `_work/brieftext.tl:59,63-64,76,78` and `_work/brieftext_review.tl:116-117`:
  `bin/cosmic --check types`, `bin/cosmic --make test <file>`,
  `bin/cosmic --make coverage`, `bin/cosmic --make build` — the
  type-check/single-test/coverage/build commands, assumed universal, with
  no cosmopolitan (or future third repo) equivalent named at all.
- `_work/brieftext.tl:55` (`BUILDER` step 1): "if the Change's additions
  cannot fit under the 500-line cap, STOP now" — stated as a bare fact,
  with no repo qualification, even though the cap is `cosmic`'s (and by
  copied convention `work`'s) own house rule, not a gitboard invariant.
- `_work/brieftext_review.tl:134,223` (landed this session, item
  `s2ac_B5wz`): "run `bin/cosmic --make fetch`" — a brand-new instance of
  the same pattern, added to the generic review template the same day
  this gap was noticed.

Measured live, same session: building item `YLxi_6fmt` (a `gitboard`-side
change), the builder had **no local copy of `cosmic`'s own build
machinery to consult** — `cosmic-lua/work` only consumes cosmic's pinned
binary — and had to cross-reference `embed/cosmic.mk` and `_make/fetch.tl`
in a *different repository* (`cosmic-lua/cosmic`) just to learn what
`--make fetch`/`--make build`'s console output looks like, in order to
write a filter for it. That a change to gitboard's own generic tooling
required reading a second repo's internal build recipe is itself the
signal: repo-specific mechanics have leaked into code that is supposed to
be repo-agnostic.

Contrast: `_work/product.tl` already isolates a DIFFERENT per-board
constant (`REPO`, `BOARD_REPO` — which repo this board instance tracks)
into one small, documented module with a clear doc comment explaining why
it must not be derived from a checkout's own `origin`. That's a precedent
for the shape this outcome wants, applied to a different axis: not "which
repo is this board FOR" (settled once, per board instance) but "how do I
build/gate/bootstrap THIS repo" (varies per repo the board's items touch,
and belongs to that repo, not to gitboard).

## Change

Give gitboard a small resolver for "how do I build/gate/type-check/test
THIS repo" — no checked-in data file needed, because the two cases in
scope already carry everything the resolver needs without one:

- **a repo that ships `bin/cosmic`** (detected by presence — `bootstrap()`
  already does this) needs no repo-specific configuration at all:
  `_make`'s entire design point is that `--make ci`, `--make build`,
  `--make test <file>`, `--check types <file>` are identical across
  every cosmic-based project, by convention, not by declaration. This
  generalizes what `bootstrap()` already does for `cosmic-lua/cosmic`
  and `cosmic-lua/work` today — it stops being a special case for those
  two names and becomes "any repo with `bin/cosmic` at its root."
- **a repo that does not ship `bin/cosmic`** (`cosmic-lua/cosmopolitan`
  today, the only one) exposes a small, fixed vocabulary of `make`
  targets instead — `bootstrap`, `gate`, `check-file FILE=<path>`,
  `test-file FILE=<path>` — that gitboard always invokes by name, never
  branching on the repo's identity. The repo declares its own mechanics
  by implementing these targets in its own Makefile (`cosmopolitan`
  already has one; this outcome adds four phony targets to it), not by
  writing gitboard a separate data file that has to be kept in sync
  with what the repo actually does. Presence is probed the same
  file-presence-adjacent way `bootstrap()` already works: `make -n
  <target>` (a dry run) succeeding means the target exists; failing
  (`No rule to make target`) means it doesn't.
- **the default base branch** is read from the checkout's own git remote
  (`git symbolic-ref refs/remotes/origin/HEAD`) rather than hardcoded by
  repo name or declared anywhere — it's a fact the checkout's own git
  config already carries. The item's own `base` field still overrides
  this, as it does today.
- **the file-length cap** stays fully out of this outcome's scope — the
  sibling item («YedR_ZHgk») defers that question to the repo's own
  `AGENTS.md` convention, which is a stronger fit than either a manifest
  field or a make target (it isn't a command).

`gitboard worktree`'s bootstrap, the builder/review brief templates, and
`default_base` all call this one resolver instead of matching on
`repo:find(...)` or a file's presence directly. A repo with neither
`bin/cosmic` nor the four make targets still degrades to today's
"nothing (unrecognized tree)" path, not a crash.

This item is the outcome; see its children for the buildable slices (the
resolver itself; migrating `gitworktree.tl`; migrating the
builder/review brief templates; resolving the file-cap instruction
specifically).

## Non-goals

Not designing a general plugin/extension system — a fixed, four-name
make-target vocabulary covers the one non-cosmic repo in scope today and
any future one, without inventing a new manifest format or file gitboard
has to parse. Not adding a data-file config format anywhere — an earlier
version of this outcome cited `bin/cosmic.pin`/`cosmic.literal` as
precedent for "a checked-in data file gitboard reads"; that precedent
doesn't apply once the "declare mechanics" job moves to an interface (a
Makefile target) instead of a fact (a data field) — a repo answers "how
do I gate" by being able to run `make gate`, not by writing a value
down. Not moving `_work/product.tl`'s `REPO`/`BOARD_REPO` — that answers
a different question (which repo this board instance tracks, decided
once per board) and already has the isolation this outcome wants for
the axis it actually targets (how to build a given tree, which varies
per repo the board's items touch). Not migrating cosmic-lua/cosmopolitan's
own recognition today beyond adding the four Makefile targets — this
outcome makes a repo's build mechanics a fixed interface contract
instead of a hardcoded `if`/`else`, it doesn't itself add a third or
fourth repo.
