Nine source files (two substantively, seven call-site trims), README,
and tests, all on the `board` branch.

**1. `_work/store.tl` (490 lines, shrinks) — publish refuses instead
of replaying.** `publish` loses the `Revalidate` parameter, the
`Revalidate` type, and the 3-attempt rebase-repush loop (line 403's
"publish did not converge"). New behavior: one push; on rejection,
`reset -q --hard HEAD~1` — exact, because `save` writes one mutation
as one commit — then `rebase_onto_remote` (nothing local remains, so
no conflict path), and return `false, store.LOST_RACE`.
`LOST_RACE < const >` is exported on the record: "lost the push race —
the mutation was dropped whole and the checkout re-synced; re-run the
verb against the current board". Update the module header's
rejected-push prose.

**2. `_work/gitgate.tl` (378 lines, shrinks) — no post-race
revalidate.** `commit_and_publish` becomes save-then-publish; the WIP
revalidate closure and its `from`/`force`/`vacated` plumbing are
deleted — a re-run verb re-applies `wip_refusal` (which keeps
`vacated` and force semantics up front, unchanged) and every other
guard against merged state, which is strictly more than the closure
re-checked. New signature:
`commit_and_publish(s, it, body, message, also?)`.

**3. Call sites trimmed to the new signature** (drop the trailing
`from`/`also-nil`/`force`/`vacated` arguments): `_work/gitverbs.tl`
lines 49, 240, 287; `_work/gitgraph.tl` 76, 134, 229;
`_work/gitreview.tl` 91; `_work/gitverdict.tl` 224;
`_work/gitcompare.tl` 68; `_work/gitgate.tl` 334 (`set_in_place`).

**4. `README.md` (97 lines).** The two rejected-push paragraphs now
say: a rejected push drops the mutation whole and refuses, naming the
re-run; the re-run applies every gate to the merged board. (The
matching sentence in `skills/work/SKILL.md` lives on `main` and is a
separate PR once this lands — noted in this PR's body.)

**5. Tests.**
- `_work/gitgate_test.tl` (~140 lines): the four rebase-revalidate
  cases become the new contract — a lost race returns
  `store.LOST_RACE` and the SECOND `commit_and_publish` (the re-run)
  publishes; the over-limit-arrival case's refusal now comes from the
  verb's own up-front gate on re-run, not from publish.
- `_work/store_test.tl`: `test_publish_cas_refuses_over_limit`
  becomes `test_publish_drops_a_lost_race`: the loser gets
  `LOST_RACE`, its local log equals origin's (commit dropped, synced),
  and its item file reads the remote's state.
- New `_work/publish_race_test.tl` over `fixture.init_shared`,
  pinning the two filed shapes end to end through real verbs:
  - `test_a_lost_block_race_cannot_land_a_cycle` — A publishes
    `block X on Y`; B, stale, runs `cmd_block Y on X`: the publish
    refuses with `LOST_RACE`, and re-running `cmd_block` on the
    synced checkout refuses naming the cycle. `status` reports no
    cycle at any point.
  - `test_a_lost_done_race_rephases_the_parent` — two children of one
    parent; A `cmd_done`s child1 and publishes; B, stale, `cmd_done`s
    child2: refused with `LOST_RACE`; the re-run computes
    `rephased_parent` against merged state and the parent returns to
    `backlog`.
