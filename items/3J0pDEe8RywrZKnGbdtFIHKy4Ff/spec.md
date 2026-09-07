## Evidence

Refining outcome `AP77_4XCs` this session touched it and all four of
its children: five independent `gitboard spec ID FILE --base BASE`
calls plus four independent `gitboard set ID --title TITLE` calls, no
two of them atomic with each other. Nothing went wrong this time (each
call succeeded in sequence, and a failed compare-and-swap on any one of
them would have surfaced as an ordinary refusal rather than silent
corruption), but the shape — revise an outcome and a batch of its
children together after a refinement pass — is a natural unit gitboard
has no single verb for today; a partial failure partway through leaves
the subtree in a mixed old/new state with no built-in way to detect
that beyond re-reading every item by hand.

This is filed as a research item, not a ready Change: it isn't yet
clear whether this is common enough across real refinement sessions to
justify a new verb (versus, say, a thin wrapper script, or nothing —
N sequential calls may simply be fine at the scale this board actually
operates at).

## Change

Research: survey how often a single refinement or review pass touches
more than one item's spec or fields in the same sitting (grep gitboard's
own session logs or board history for multi-item edit sequences, if a
record of past sessions' tool calls exists to search), and record
findings plus, if warranted, a follow-up item proposing a specific
mechanism (a `gitboard batch` verb reading a list of `{id, file, base}`
edits and applying them as one commit or refusing atomically; or a
documented convention for staging N specs before applying any, so a
mid-sequence refusal is caught before any write lands) — or a finding
that the current N-calls approach is adequate and no change is needed.

## Non-goals

Not designing or building a batch-edit verb in this item — that is a
follow-up item's job if the research concludes one is warranted.

## Access

cosmic-lua/work, read only; no other repository.
