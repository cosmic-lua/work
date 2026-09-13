`_work/gitverdict.tl`: record first, land second. An `accept` writes
the verdict commit exactly as `--no-land` does, then attempts the
landing; a landing failure is reported on the verdict line after the
recorded outcome — `gitboard-verdict: accept on <id8>: awaiting merge
— landing failed (<status> <path>: <message>), land it by hand` — and
the verb exits 0 (the verdict stands). `_work/gitverdict_land_test.tl`:
a fake transport whose GraphQL call returns 403 → the verdict is
recorded and the line names the failure; the merge-succeeds and
auto-merge-succeeds cases unchanged.
