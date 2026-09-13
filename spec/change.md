AGENTS.md, the "## Testing" section: immediately after the fenced block
that ends with `o/bin/cosmic --make benchmark           # run every
*_benchmark.tl`, add one paragraph (measured 2026-09-06: `grep -n
'check types' AGENTS.md` → only line 111, the warnings-are-errors bullet
under Language and Conventions; the Testing section never mentions it):

**`--check types` on a file that requires a sibling you edited in the
same session resolves that sibling against the LAST BUILD's embedded
snapshot, not live disk** — run `bin/cosmic --make build` before
checking the caller of a module whose signature just changed, or the
checker reports the old arity — `wrong number of arguments (given 2,
expects 1)` against a two-parameter signature is the shape of it. (The
paragraph carries no item handles, PR numbers or dates: docs-style.)

No other file changes. Gate: `bin/cosmic --make ci`.
