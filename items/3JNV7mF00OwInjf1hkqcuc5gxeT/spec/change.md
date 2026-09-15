`gitboard find` missed an item that `gitboard new`'s own similarity check
surfaced immediately, and the miss caused a false report to the goal owner.

Measured: searching for an already-filed defect about the board bootstrap,

    gitboard find "sync fetch bootstrap format marker"
    gitboard-find: 0 hit(s)

The item existed: «dOmj_JNWN», titled "skills/work/SKILL.md's bootstrap tells
sessions to run `gitboard sync`, a deprecated no-op — a fresh sibling clone
shows 0 items until `refresh --execute` runs". Filing a new item on the same
subject printed it as the top `similar:` line without being asked.

On that 0-hit result I told the user the defect was unfiled. The doctrine makes
`find` the duplicate check — `help build`: "search first — `gitboard find
'<phrase>'` in the board checkout answers 'already filed?'" — so a false
negative there produces exactly the duplicate work the step exists to prevent.

This is research, not a known fix: establish why the two paths disagree.
`find` is `_work/cachequery.tl`'s `cmd_find`
(`grep -n "cmd_find" _work/cachequery.tl`); `new`'s similarity is a different
reader (`grep -rn "similar:" _work/*.tl`). Determine whether the gap is
tokenisation, the fields each searches, ranking cutting off a real hit, or a
stale cache — then either make `find` use the similarity path or state in
`help find` what it does not search.

Deliverable: findings recorded, and a follow-up item for whichever fix the
finding names.
