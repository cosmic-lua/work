One `set` verb repairs the three destination-fact fields an item can
carry but no verb can change after open: `title`, `repo`, and a NEW
`base` (the branch the item's PR targets). This consolidates three
captures of the same gap shape: retitle (three sessions hand-edited
item files in four days — evidence retained below), repo-after-open
(3ID0uFdf: a cross-repo destination learned late has no verb, HTTP
404s at handover), and base-branch (3ISQBIua: non-main targets live
only in prose and nothing catches a PR opened against the wrong
base). Both siblings are blocked on this item and verified against
it when it lands.

Measured 2026-08-29: gitverbs.tl is 494/500 — no room — so the verb
lives in `_work/gitgraph.tl` (234 lines, home of new/attach/block)
or its own `_work/gitset.tl` if graph would pass ~460. item.tl:127
declares `repo: string | nil` with a shape check at :200; there is
no base field. gitgate.handover_refusal is at gitgate.tl:178
(291-line file). Dispatch is a flat if-chain in gitboard.tl.

1. `gitboard set ID --title T | --repo OWNER/NAME | --base BRANCH`
   (at least one flag; multiple compose). Walls, enforced by the
   verb: ONLY these three fields — claim, pr, verdict, resolution,
   parent, blocked_by, lane have their own verbs and gates, and
   `set` refuses them by not existing for them. Repo keeps its
   :200 shape check; base takes a plain branch-name shape
   (`^[%w%-%._/]+$`). Setting on a done item refuses (history).
   The mutation commits as `set <id8> <field>[ <field>...]` — the
   VALUES stay out of the subject (titles are long); the diff
   carries them.
2. `_work/item.tl`: add optional `base: string | nil` beside repo,
   with encode/decode and the shape check.
3. The base gate: `gitgate.handover_refusal` additionally refuses
   when the item carries a non-empty `base` and the PR's base ref
   (gh.pull already returns the PR — measure which field carries
   the base ref and extend gh.pull if it does not) disagrees:
   `REFUSED: PR #N targets <actual>, the item says <base> — retarget
   the PR or set --base`. An item with NO base field is ungated
   (today's behavior, and board-machinery items whose PRs target
   `board` stay valid without backfill).
4. `show ID` renders repo and base on their existing field lines
   (measure how repo renders today and match).
5. Tests in the verb file's own `_test.tl`: set title/repo/base
   round-trip through a real store; refusal on a done item; refusal
   on an unknown flag; the base-gate refusal (PR base mismatch) and
   pass (match, and absent-base ungated) — mutation-verify the gate
   test goes red when the gate comparison is removed.
