# AGENTS.md

`CLAUDE.md` is a symlink to this file. Edit this file only.

Three documents divide the ground and none repeats another.
[`README.md`](README.md) describes the system: board format, storage and
publication protocol, migration, release. `gitboard help <topic>` serves the
doctrine, which changes with the board. This file says how to change the
machinery, and carries only what is specific to doing that here.

## Repository

Source changes land on `main`; live board state lives on `refs/heads/state`.
Never mix the two. README's storage section defines what that tree holds.

- `_work/`: Teal modules and tests
- `cmd/gitboard/`: binary entry point
- `_perf/`: benchmark scenarios over a synthetic board, with their own
  daily workflow
- `_fuzz/`: fuzz driver, shrinker, and input sources
- `docs/design/`: storage and ordering contracts
- `experiments/native/`: semantic and migration campaigns
- `bin/cosmic`, `bin/cosmic.pin`: the pinned build runtime
- `.cosmicignore`: keeps board state (`items/`, `lanes_state.tl`) out of the
  build model, so a tree holding both still builds
- `o/`: generated output; never commit it

The board format, publication protocol, and operator recovery procedures are
contracts. Read the relevant design document and `gitboard help <topic>`
before changing them. `bin/cosmic --make build` produces the binary those
topics come from: `o/bin/gitboard help` lists the verbs, `help TOPIC` serves a
doctrine topic, and `brief` combines it with an item's current facts.

## Working safely

Use an isolated clone or worktree. Do not share a stash or build directory
with another session.

Operate board state only through `gitboard`. Never hand-edit item data and
never push `refs/heads/state` directly. Source changes use a branch and a pull
request against `main`, the branch named for the item it carries. Merged
branches are not deleted, so the remote holds thousands of them; they are
history, not active work.

Product changes target the repository named by their item. Pull requests here
change the machinery.

Keep changes inside the requested scope. Record adjacent findings as board
items rather than widening a diff. Preserve unrelated changes already in a
working tree.

## Code

Teal (`.tl`), built by the pinned cosmic. The conventions are cosmic's own,
recorded in cosmic-lua/cosmic and enforced from that binary: the naming
charter, the 500-line file cap, the fallible-return shapes (`T | nil, string`
for a value, `boolean, string` for an effect), and the trailing annotation a
deliberate throw, assertion, or process exit carries. They are not restated
here, because a copy here would go stale the day the charter moves. Run the
gate and read what it says.

What is specific to this repository: the root is the module root, a leading
underscore marks internal code, and nothing here is published API — so `---`
documentation on an exported function is a courtesy to the next reader rather
than a gate.

Tests live beside their source as `*_test.tl`. Add a focused regression for
each behavior change. The store's tests run `git` inside the checkout, and
where the checkout's owner differs from the running user — a container, a
fresh runner — git refuses it as a foreign repository. The test failure does
not name that cause, so set `git config --global --add safe.directory <path>`
before the first run.

## Validation

Prefer the narrowest useful checks while iterating:

```sh
bin/cosmic --make fetch
bin/cosmic --make build
bin/cosmic --make test _work/<file>_test.tl
```

Before pushing, run:

```sh
bin/cosmic --make ci
```

Read the final `ci: PASS` or `ci: FAIL` verdict; do not hide its exit status
behind a pipe. The `board` workflow runs that same gate and is the recording
environment for `.cosmic-coverage`, which it marks with
`COSMIC_COVERAGE_ENV=1`. Coverage moves with the host, so a local number is
not the CI number: never regenerate the whole floor locally. To adjust one
row, measure it with `bin/cosmic --make coverage`, change that row alone, and
carry the measured basis with it.

## Landing

Merge commits and rebase merges are disabled and the merge queue is required,
so there is no merge to perform: mark the draft ready, then enable auto-merge
to enqueue it. A direct merge call is refused.

The queue validates a newly created `merge_group` commit. Read the check runs
on that commit — for Actions the combined commit status can be empty. Once the
queue completes, verify both that the pull request merged and that `main`
points at the queue commit.
