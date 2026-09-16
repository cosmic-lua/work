`snippets` in `_work/prosecommands_test.tl` lifts an inline code span only
when it contains `gitboard <word>`, so the doctrine's dominant form — a
backticked bare verb example such as `rank ID --before X` or `done ID
--landed SHA` — is never checked, and a deprecated `sync` written that way
passes. Its line scan also accepts a bare `gitboard ...` line only after a
blank or colon-terminated line, so an indented command after ordinary prose
is dropped.

Extend `snippets`:

1. An inline span whose first token is a registered command name
   (`gitcommands.CSPEC.commands`, deprecated ones included) is checked as
   `gitboard <span>` when it has a second token, or when the span is exactly
   a deprecated verb's name. A single-token span naming a live verb
   (`next`, `show`) is prose and is skipped.
2. A line indented by two or more spaces that starts with `gitboard <word>`
   is a command when `<word>` is a registered name, whatever the previous
   line was; a line whose word after `gitboard` is not a registered name
   stays prose (`gitboard only — never GitHub labels` in `help orchestrate`).

Keep every existing extraction and `check_command` as they are. Add a
table-driven unit case over `snippets`/`check_text` covering: a
bare-backtick example with flags, a bare backticked `sync`, a single live
verb skipped, an indented command after a prose line, a prose line starting
with `gitboard`. The live corpus's bare examples are expected to be valid
today; one the extended gate turns red is a finding to report in the final
message, not a wording change to make here.
