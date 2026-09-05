## Evidence

`_work/gitboard.tl:147-148` documents `new`'s `--repo` flag as:

    {long = "repo", arg = "OWNER/NAME",
      help = "the repo its PR lands in; default is the board's origin"},

But `_work/item.tl:264` refuses `--repo` (along with `claim`/`reviewer`/`pr`/
`verdict`/`base`) on a root item: `"claim/reviewer/pr/verdict/repo/base
belong to worked items, not roots"` — a constraint the printed `--repo`
help text never states. A session filing a root-level item (no `--parent`)
with `--repo` only discovers the refusal at call time. Observed directly
this session (`vIh5_25NV`, the 2026-09-05 `/work 9 --routine` friction
log): `gitboard new ... --repo cosmic-lua/work` on an unparented item was
refused with exactly that message, costing a retry (file without `--repo`,
then `attach`) that a one-line help note would have avoided.

## Change

In `_work/gitboard.tl`, extend the `--repo` flag's `help` string (line 148,
in the `new` command's `CSPEC`) to state the root refusal, e.g.:

    help = "the repo its PR lands in; default is the board's origin. "
      .. "Refused on a root item — attach it under a parent first, or "
      .. "the parent supplies it."

Update any `_work/gitboard_test.tl` assertion that pins the exact old
string.

## Non-goals

Not changing the refusal behavior in `_work/item.tl` itself — this is a
help-text-only fix. `new` exposes no `--base` flag at all (only `set` and
`spec` do), so there is no parallel gap to close there.
