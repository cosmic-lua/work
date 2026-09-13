In `docs/decisions/d30-throw-exit-boundaries.md`, correct the grammar
sentence in the decision section — today (measured 2026-08-27,
`grep -n 'on an .os.exit' docs/decisions/d30-throw-exit-boundaries.md`
→ line 52):

> `-- exits: <why>` on an `os.exit(` line

becomes

> `-- exits: <why>` on an exit call's line (`os.exit(`, `unix.exit(`)

Per the decide skill this is a **correct** (a detail the tree outgrew;
no claim changes): edit in place, no status change, no amendment
bullet. Evidence the tree outgrew it: six post-fork children exit via
`unix.exit(` and all carry `-- exits:` markers — measured 2026-08-27,
`grep -rn "unix.exit(" cosmic/quicksand | grep -v _test` →
`cosmic/quicksand/proxy.tl:135,152,159,161`,
`cosmic/quicksand/proxy/serve.tl:404`, `cosmic/quicksand/init.tl:127`
— and the enforcement lint (PR #1412) reads the receiver, covering
both spellings.
