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
