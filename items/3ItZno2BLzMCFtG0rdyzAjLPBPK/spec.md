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

AGENTS.md, the "## Testing" section: immediately after the fenced block
that ends with `o/bin/cosmic --make benchmark           # run every
*_benchmark.tl`, add one paragraph (measured 2026-09-06: `grep -n
'check types' AGENTS.md` → only line 111, the warnings-are-errors bullet
under Language and Conventions; the Testing section never mentions it):

**`--check types` on a file that requires a sibling you edited in the
same session resolves that sibling against the LAST BUILD's embedded
snapshot, not live disk** — run `bin/cosmic --make build` before
checking the caller of a module whose signature just changed, or the
checker reports the old arity (three builders hit this on 2026-09-06:
«AjLP_BPK»'s own evidence plus cosmic#1755's `wrong number of arguments
(given 2, expects 1)` against a two-parameter signature).

No other file changes. Gate: `bin/cosmic --make ci`.
## Non-goals

Changing `--check types`'s actual resolution behavior (out of scope; the snapshot
approach may be intentional/cheap and is not what's being questioned here — only its
being undocumented). Any change to the build pipeline itself.
