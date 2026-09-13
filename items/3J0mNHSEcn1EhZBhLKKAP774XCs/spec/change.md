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
