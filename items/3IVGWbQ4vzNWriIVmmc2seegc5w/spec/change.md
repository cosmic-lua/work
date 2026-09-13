Two one-line edits on `main`, in `skills/`. Nothing in `_work/` or on the
`board` branch — that change already landed as whilp/cosmic#1461.

`gitboard spec` now refuses a write onto an item that already carries a
sidecar unless the call also names `--base FILE` holding the text the caller
read. Measured now: `grep -rn "gitboard spec" skills/ docs/ AGENTS.md
CLAUDE.md` returns exactly 2 hits, and both are wrong in the same way.

**1. `skills/work/SKILL.md:332`** — the slice loop's detail-drift step reads
`refresh the measured lines in place (`gitboard spec ID FILE`, one commit,
noting "re-measured at pull")`. A session that runs that literally is refused,
because the re-measure is by definition a write onto a sidecar that already
exists. Replace the parenthetical with one that names the VERB and the
property a caller has to satisfy, not the flag:

```
     refresh the measured lines in place (`gitboard spec`, written back
     against the text you read, as one commit noting "re-measured at
     pull") and proceed.
```

**2. `skills/optimize/SKILL.md:275`** — `(`gitboard spec` replaces the
sidecar)` describes a verb that no longer replaces one unconditionally.
Replace with:

```
(`gitboard spec` replaces the sidecar, against the text it read)
```

**Name the verb, never its flag list.** `skills/work/SKILL.md:74` already
fixes this rule — "the verbs are the tool's to describe, not this skill's",
because `gitboard help <verb>` is generated from the CLI and cannot drift.
Writing `--base FILE` into either file would be true today and stale at the
next flag change, which is exactly how these two lines got wrong. What the
skills owe the reader is the SEMANTIC — a spec write is a compare-and-swap, so
keep the text you read — and `gitboard help spec` owns the spelling. Measured:
`wc -l skills/work/SKILL.md` is 439 and `skills/optimize/SKILL.md` is 282,
both well under the 500-line cap, and neither edit changes a line count by
more than 2.
