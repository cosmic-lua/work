## Evidence

`bin/gitboard next` (2026-09-06 18:20Z, board at 94e41c5) recommended
«5P4r_VUqR» as "highest-ranked todo item passing the spec bar" while
that spec's `## Change` opened with a Ready-when naming «omzs_ww5P»
and «SmAQinD», neither done. Caught by hand, 3 orchestrator calls;
an unattended pass would have pulled, briefed, and bootstrapped a
builder for work that cannot start.

The doctrine already makes the sentence a command: `git grep -n 'Ready
when' -- _work/doctrine.tl` → 167 ("states that fact as a command and
the output that means ready, in prose at the top of `## Change`") and
199 ("a `Ready when` command runs first, and not ready is a bare
drop"). The mechanism is puller discipline: a take-then-drop cycle at
best, a wasted pull at worst; the tool never runs it.

The one place a spec's tree-facts are already evaluated and rendered
on a read: `git grep -n 'absent: \|tight: ' -- _work/overlap.tl` → 165,
171, inside `headroom_lines` (`_work/overlap.tl:161`), consumed by
`_work/gitshow.tl:299`. The two gates a pull passes: `_work/gitready.tl:113`
`ready_problems` (what `take` refuses on, `_work/gitverbs.tl:199`) and
`_work/gitview.tl:213` `act.passes_bar` inside the PURE `next_report`;
`next`'s live half is `next_report_live` (`_work/gitview.tl:419`).
Sizes: `wc -l _work/overlap.tl _work/gitready.tl _work/gitview.tl` →
265, 184, 490 (gitview is tight: 10 lines left).

## Change

One mechanism: `_work/overlap.tl` gains `ready_when(body): string | nil`.
It finds, in the `## Change` section, the first sentence beginning
`Ready when:`; when that sentence carries at least two backtick spans,
the first span is run as a command (`cosmic.proc`, cwd = the process
cwd, stdout captured, stderr discarded, 10 s cap) and its trimmed
stdout compared with the second span. Mismatch returns
`not ready: \`CMD\` printed \`<first line of stdout, or exit N>\`; ready
means \`OUT\``; a match, no sentence, or a sentence with fewer than two
spans returns nil (the prose form is never run).

Two consumers, both existing gates:
- `_work/gitready.tl` `ready_problems`: append the line when non-nil,
  so `take` refuses the pull with it (`not ready` is a refusal, not
  the doctrine's drop — the drop is now moot because the pull never
  happens).
- `_work/gitview.tl` `next_report_live`: evaluate `ready_when` for
  the recommended head only (never the whole queue — each is a
  process spawn) and, when it returns a line, print it as a
  `not ready:` line and recommend the next candidate instead, the
  same way a queued-accept head is skipped there today.

Tests: `_work/overlap_test.tl` — a body whose sentence runs `printf
ready` against `ready` → nil; against `done` → the `not ready:` line
quoting `ready`; a prose-only sentence → nil, and no process spawned
(the fixture command is `false`, which would otherwise mismatch).
`_work/gittake_test.tl` — `take` on an item whose Ready-when
mismatches refuses with the line. `_work/gitview_live_test.tl` —
`next` with a mismatching head recommends the second candidate and
prints the line.

`help bar` (`_work/doctrine.tl:167`): amend the Ready-when paragraph
in place to state the evaluated shape — "Ready when: `CMD` prints
`OUT`" — and that `next` skips and `take` refuses a not-ready item,
so the drop-bare sentence at 199 is replaced by "the tool checks it".
`_work/doctrine_test.tl:74-88` asserts the old wording; update those
assertions to the new sentences.

## Non-goals

No new item field, no date, no dependency edges between items — the
criterion stays whatever the command prints. No evaluation on `show`
(a read that must stay cheap) and none for candidates below the head.
No change to `absent:`/`tight:` lines.
