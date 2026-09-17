Builder stopped at the live-corpus check: the extended rule 1 turned exactly
one example red, `set -o pipefail` in the builder brief (`_work/brieftext.tl`),
a shell builtin whose first word collides with the `set` verb; every doctrine
bare span and indented command was valid. Refined rule 1 so a bare span is a
command only when a later token is a long `--flag` or an uppercase placeholder,
or the span is exactly a deprecated verb; the shell line has neither.