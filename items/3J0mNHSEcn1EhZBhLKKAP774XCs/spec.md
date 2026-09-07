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

Give each product repo a small, explicit place to declare its own build
mechanics — a manifest gitboard reads instead of hardcoding, checked into
the PRODUCT repo (not `cosmic-lua/work`) alongside its `AGENTS.md`, in
whatever plain-data shape this project's own conventions favor (this repo
already has a precedent for "a tool reads a small checked-in data file it
never executes" in `bin/cosmic.pin`; `cosmic.literal` is the project's
own preferred data format elsewhere). At minimum it should answer the
questions gitboard's templates currently answer by hardcoding a repo
name:

- the bootstrap command(s) for a fresh worktree (or none)
- the full-gate command
- the type-check-one-file command
- the run-one-test-file command
- the default base branch
- whether/what file-length cap the repo enforces (or: defer entirely to
  the repo's own `AGENTS.md`, which `brieftext_review.tl:105` and
  `doctrine.tl:105,288` already treat as binding — the more consistent
  answer, since gitboard elsewhere already says "the repo's AGENTS.md
  binds" rather than asserting the number itself)

`gitboard worktree`'s bootstrap, the builder/review brief templates, and
`default_base` all read this instead of matching on `repo:find(...)` or a
file's presence. A repo gitboard has never seen (no manifest) degrades to
today's "nothing (unrecognized tree)" path, not a crash.

This item is the outcome; see its children for the buildable slices
(introducing the manifest and its reader; migrating `gitworktree.tl`;
migrating the builder/review brief templates; resolving the file-cap
instruction specifically).

## Non-goals

Not designing a general plugin/extension system — a small, static,
checked-in data file per repo is the whole ask, matched to how this
project already does "config" everywhere else (a pin, a literal). Not
moving `_work/product.tl`'s `REPO`/`BOARD_REPO` — that answers a
different question (which repo this board instance tracks, decided once
per board) and already has the isolation this outcome wants for the
axis it actually targets (how to build a given tree, which varies per
repo the board's items touch). Not migrating cosmic-lua/cosmopolitan's
own recognition today beyond what already exists — this outcome makes
adding a third or fourth repo a data change instead of a gitboard
release, it doesn't itself add one.
