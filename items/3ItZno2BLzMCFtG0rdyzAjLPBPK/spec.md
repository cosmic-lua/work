## Evidence

Found independently by two builder agents in the same orchestrator pass
(items `3ItPENxrFPWvwsBntdoCtYHGmrg` and `3ItPHXvt4WG9OoCKqKUev5VlF1l`, 2026-09-05),
each losing ~10-20 minutes to the same confusion.

AGENTS.md's Testing section recommends: "Between edits, `bin/cosmic --check types
<file>` on the files you touched." When `<file>` is under `cosmic/**` and requires a
SIBLING module that was ALSO just edited in the same session, `--check types`
resolves the `require("cosmic.<mod>")` against the last BUILD's embedded snapshot
(`o/cmd/cosmic/embed_gen/embed/...`), not the live, just-edited disk content. The
result is a phantom "unknown type"/stale-signature error from the pre-edit version
of the sibling, which reads exactly like a real type error in the edited file, until
the builder thinks to run `bin/cosmic --make build` to refresh the snapshot.

Both builders independently spent real time (one ~20 minutes, the other ~20 minutes)
tracing this before discovering the fix, because AGENTS.md's own instruction doesn't
flag the distinction between checking a single file with no cross-module edits
(works fine against the snapshot) and checking a file against a sibling edited in
the same pass (needs a fresh build first).

## Change

One sentence added to AGENTS.md's "Testing" section, immediately after the existing
"Between edits, `bin/cosmic --check types <file>`" line: note that a cross-file
check against a sibling module edited in the same session needs `bin/cosmic --make
build` first, since `--check types` otherwise resolves `cosmic.*` requires against
the last build's embedded snapshot rather than live disk.

## Non-goals

Changing `--check types`'s actual resolution behavior (out of scope; the snapshot
approach may be intentional/cheap and is not what's being questioned here — only its
being undocumented). Any change to the build pipeline itself.
