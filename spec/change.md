Decision (from the capture's two options): teach the scan — the
lexical rule is bounded, and the risk asymmetry decides the shape:
over-refusal is today's annoyance, under-refusal recreates the
silent-prefix bug the scan exists to prevent, so every ambiguous
shape keeps refusing.

`cosmic/sqlite/sqltext.tl`, has_multiple_statements: the scan reads
whole words (uppercased, so identifiers never match keywords by
substring) and runs a small state machine — `CREATE` then
(`TEMP`|`TEMPORARY`)* then `TRIGGER` arms it; any other word after
CREATE disarms; the body opens at `BEGIN` with depth 1; inside the
body `CASE` increments and `END` decrements (END terminates only
CASE and TRIGGER in sqlite), and semicolons at depth >= 1 are
internal; depth 0 returns the scan to normal, where a `;` counts as
today. Quoted strings, bracketed/backticked identifiers and comments
skip exactly as now, so a bracketed [end] column can never close a
body. A semicolon between TRIGGER and BEGIN (illegal SQL) counts as
top-level — conservative.

Tests: sqltext gains its own `sqltext_test.tl` — the module's floor
is the file's lowest (29/41) with the skip branches untested —
covering: the capture's trigger accepted; trigger + trailing `;`;
trigger followed by a second statement refused; CASE...END inside a
body; CASE...END outside any trigger followed by a statement
refused; CREATE TABLE with a `trigger` column name; quoted/bracketed
`end`; comments between the keywords; the existing string/comment/
bracket skips pinned. `init_test.tl` (or the nearest exec test file)
gains the end-to-end case: exec creates a trigger and a row insert
fires it.
