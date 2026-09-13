**Do not add the `stats` triage-latency metric here.** Reporting filed →
adopted-or-closed latency needs a new derivation over `work:finding` label
add/remove events in `_work/stats.tl`, which is more code than items 1–5
combined and is independently verifiable. It is a follow-up child, not part of
this slice; item 5's `status` counter is the pressure that ships now.

**Do not add a new phase.** A `work:inbox` to the left of `plan` was considered
and rejected: the `work:finding` marker plus the existing `counts_against_limit`
hook already express the distinction, and a phase would touch `PHASES`, the pull
order, the label set, and every verb. Revisit only if the finding counter shows
the marker is not enough.

**Do not change any number in `LIMITS`.** `plan` stays 12. The hard rules forbid
widening a limit to make a move succeed, and after this change `plan` sits at
15/12 — the limit correctly reporting a real overload. The response to that is
draining toward `ready`, not a bigger cap.

**Do not gate adoption on `plan` slack.** The original item 3 asked for it and
there is no seam to hang it on: there is no adopt verb — adoption is dropping the
`work:finding` label plus adding a goal trace to the body, and `_work/verbs.tl`
has only `cmd_status`/`cmd_next`/`cmd_check`/`cmd_move`/`cmd_new`/`cmd_edit`, so
no code path observes an adoption happening. Confirmed from the other side on
2026-08-17, when a planner adopting #1245 at triage had to make a hand-rolled
label call for exactly that reason. A gate here is blocked on an adopt verb
existing — the board-tool write-verb gap tracked in #1204 — and this slice must
not build one.

**Do not exempt `work:enable`.** A planner-filed countermeasure has a goal trace
and is adopted work; it belongs in the count.

**Do not change the finding's tracing exemption, the never-refused write, or any
other phase's counting.** `counts_against_limit` gains one disjunct and nothing
else moves.
