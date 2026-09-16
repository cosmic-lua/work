In _work/gitboard.tl's shared main dispatcher, when flags.command returns
an error, write the existing parser diagnostic and its newline to stderr,
return the existing failure status, and omit the appended top-level usage
and doctrine listing. Keep the parser's diagnostic text unchanged. This
applies to parse errors for every verb, not only new.

Regression tests through the actual dispatcher must cover unknown options
on new and take, a missing option value on snapshot, and an unknown command.
Assert failure status, empty stdout, and the preserved diagnostic alone on
stderr, with no appended usage or topic listing. Explicit top-level and
verb help, doctrine help and no-argument help retain their current successful
output. Preserve new's existing -- terminator handling for dash-leading
titles; retain or add a regression proving storage is verbatim.
