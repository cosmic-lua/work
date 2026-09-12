## Evidence

Three statements in `«uOsC_KV6H»` (PR #151) describe a design that the
same change replaced, or cite a rule that does not say what they claim.
All three were found by that item's re-reviewer and held out of the push
so the reviewed bytes were exactly what landed.

**1. `_work/brieftmpl_source.tl:5-8` describes a test that no longer
exists.** Its header says the module was

    Split from the generator so the generated modules can be checked
    against their templates by an ordinary test — requiring the generator
    itself would RUN it, and a drift guard that rewrites the files it is
    checking proves nothing.

After the rework there is no such test: the drift check moved into
`_work/brieftmpl_gen.tl`, and the guard now IS the thing that rewrites
the files it checks. The split is still justified — the remaining test
needs `UNITS`/`tokens_of`/`OUT_DIR` without running the generator — but
the stated reason is no longer the real one.

**2. `_work/brieftmpl_gen.tl:25-27` overstates the `reads-declaration`
rule.** It says:

    Nor can a test be told to look: a test's result is recorded against
    its declared inputs, a declaration may not name a build output.

`cosmic --docs guide.lint` under `reads-declaration` carves out
`o/<dir>/<stem>_gen/**` where `<dir>/<stem>_gen.tl` exists — so
`o/_work/brieftmpl_gen/` WOULD have been a legal declared input, and a
generator-written drift record read by a declared test was available.
The chosen design is still better (no ferry file; it fires on verbs no
test runs under), but the comment rests it on a rule that does not rule.

**3. The commit message's load-bearing fact is the opposite of the one
it argues.** It says the check "runs on every verb". What actually makes
the guard sound in CI is that `ci` is the FIRST generator-running verb
there: `board.yml` runs `bin/cosmic --make fetch` before `--make ci`, and
`fetch` does not run generators (`fetch: PASS (0 pins)`, no `generate`
line, clean tree after). Had `fetch` run them, it would have repaired the
tree and `ci` would have gone green over a stale commit.

The reviewer reproduced the corresponding false green directly: running
ANY generator-running verb before `--make ci` in the same checkout makes
`ci` pass over committed drift. That is inherent to a self-clearing guard
and harmless in CI, which is cold and runs `ci` first — but it is the
first thing a reader needs to know, and nothing says it.

## Change

Correct the two comments so each describes what is actually there:
`_work/brieftmpl_source.tl`'s header giving the real reason for the split,
and `_work/brieftmpl_gen.tl`'s giving the real reason a declared-input
test was not used (the carve-out exists; the ferry file and the
verbs-without-tests gap are why it was not taken).

Record, where the generator's check is documented, the two facts a reader
needs to trust it: that it is sound in CI because `ci` runs before any
other generator-running verb there, and that a warm local checkout which
has already run such a verb will pass over committed drift.

## Non-goals

Not changing the drift check, the generator, or any test — `«uOsC_KV6H»`
settled the design and this is about what the tree says about it. Not
changing the `reads-declaration` lint or its documented carve-out. Not
revisiting whether a build-step refusal is the right home.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
