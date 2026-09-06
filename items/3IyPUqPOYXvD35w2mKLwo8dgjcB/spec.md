## Evidence

Ending «npTS_YYtP» not-planned, the orchestrator tried to record the disproof on its spec: `gitboard spec ID FILE` → "REFUSED: claimed by … needs --force --why"; with `--force --why` → "REFUSED: already has a spec — pass --base FILE holding the text you read"; with `--base` holding what `gitboard show ID` had printed under `--- spec ---` seconds earlier → "REFUSED: spec changed since you read it — re-read it (`gitboard show`) …". Three refusals, and the evidence never reached the board. `show`'s rendering of the spec is not byte-equal to the sidecar (`show` was the only reader the refusal named), so the `--base` contract cannot be met from the tool's own output.

## Change

`gitboard show ID --raw` prints the spec sidecar byte-exactly and nothing else (no header fields, no history, no trailing verdict line), so `show ID --raw > base && spec ID FILE --base base` round-trips; `spec`'s "pass --base FILE" refusal names `show ID --raw`, not `show ID`. Test in `_work/spec_test.tl` (or the show verb's test file): `show --raw` output fed back as `--base` is accepted for an unchanged spec, and a one-byte change between read and write is still refused.

## Non-goals

No change to the concurrency rule itself (last-write-wins stays refused); no change to `show`'s default rendering.

## Access

cosmic-lua/work, read and write on a branch; no other repository.

## Ready when

`gitboard show ID --raw | gitboard spec ID NEW --base /dev/stdin` (or the two-step equivalent) succeeds on an unchanged spec, and `gitboard spec` with no `--base` names `show ID --raw` in its refusal.
