Two behaviours, three source files and two test files, all on the `board`
branch.

**1. `_work/store.tl` — the trail covers the sidecar.** `history` (line 412)
narrows an item's log to `items/<id>.tl` alone (line 416), so a `spec` commit —
which touches only `items/<id>.md` — never reaches `show`'s trail. Add the
sidecar to the same pathspec, one line below it, and say so in the function's
doc comment. Measured now: `wc -l < _work/store.tl` is 490, 10 lines of
headroom under the 500-line cap, and this adds at most 3.

**2. `_work/gitverbs.tl` — `spec` is a compare-and-swap.** `cmd_spec` (line 40)
writes the sidecar unconditionally, so a session that reads a sidecar, refines
it for minutes, and writes it back replaces whatever landed in between. Give it
a fourth parameter `base: string` — a path, or nil — and one rule before it
commits:

- the base text is `""` when `base` is nil or `""`, else the contents of that
  file (an unreadable base is a refusal, exactly as an unreadable FILE already
  is);
- when the base text differs from `store.read_spec(s, id)`, refuse: exit 1, no
  commit, no write.

One rule, no special case: an item with no sidecar reads back `""`, which is
what a call with no `--base` compares against, so the FIRST write of a spec
still needs no flag — which is why `give_spec` and `new --spec-file` keep
working untouched.

Two refusals, both `REFUSED:`-prefixed like the ones already in this module,
each naming the recovery:

- no `--base` and the item already has a sidecar — `REFUSED: <id8> already has
  a spec — pass --base FILE holding the text you read; a write with no base is
  last-write-wins`
- `--base` given and stale — `REFUSED: <id8>'s spec changed since you read it —
  re-read items/<id>.md, re-apply your edit, and pass the re-read text as
  --base (the trail is `gitboard show <id8>`)`

This deliberately breaks the bare `gitboard spec ID FILE` that open items'
prose names — 31 sidecars mention it and 16 of those belong to items with no
`resolution` field (`grep -rln "gitboard spec" items/*.md`, cross-checked
against each `items/<id>.tl`), measured 2026-08-27. Those calls now fail
loudly with a refusal that says what to add, which is the trade this item
exists to make. Measured now: `wc -l < _work/gitverbs.tl` is 329.

**3. `_work/gitboard.tl` — the flag.** Add
`{long = "base", arg = "FILE", help = "the spec text you read, as the
compare-and-swap base"}` to the `spec` command's flag list (line 96), and pass
`d.parsed.values["base"]` as `cmd_spec`'s fourth argument in the dispatch (line
292). Measured now: `wc -l < _work/gitboard.tl` is 372.

**4. Tests.** `grep -rn "cmd_spec(" _work/*_test.tl _work/fixture.tl` returns 8
call sites today; the two whose item already carries a sidecar —
`_work/gitverbs_test.tl:137` and `_work/gitverbs_test.tl:377` — pass the text
they are replacing as the new base argument, so each keeps testing what it
tested. Then add:

- `_work/gitverbs_test.tl` (441 lines, 59 of headroom):
  `test_spec_refuses_a_write_with_no_base` — a second `cmd_spec` with no base
  is refused, `store.read_spec` still returns the first text, and the commit
  count is unchanged; and `test_spec_refuses_a_stale_base` — with a first
  writer's text as base after a second writer replaced it, the write is refused,
  and re-reading the current text as base makes the same write succeed.
- `_work/store_test.tl` (283 lines):
  `test_history_covers_the_spec_sidecar` — `store.save` an item, then `save` it
  again changing only the spec argument, and assert `store.history(s, id)`
  carries that sidecar-only commit.
