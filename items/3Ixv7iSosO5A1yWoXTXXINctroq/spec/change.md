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
