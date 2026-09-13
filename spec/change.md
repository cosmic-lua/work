`_work/gitspec.tl` (the `spec` verb): compare the incoming body to
the stored `spec.md` before writing. Identical body → no commit at
all and the verdict line `gitboard-spec: <id8>'s spec is unchanged —
nothing written` (exit 0), regardless of whether the session would
have been a new speccer. A changed body → today's path, and the
verdict line gains the size of the change: `gitboard-spec: <id8>'s
spec replaced (+N/-M lines)`. `_work/gitspec_test.tl`: an identical
body writes nothing and says unchanged; a one-line change says
`(+1/-1 lines)`.
