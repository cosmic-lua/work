1. `_work/item.tl`'s `problems(it)`: extend the existing root/non-root
   branch so a NON-root item (`it.parent ~= ""`) requires non-empty
   `repo` AND non-empty `base`, symmetric with the existing rule that
   a root requires them empty. This is the one shared gate `cmd_new`
   (`_work/gitgraph.tl:83`) and `cmd_attach` (`_work/gitgraph.tl:158`)
   already both call before committing, so the requirement lands at
   every place an item becomes parented with no new call site to
   thread it through.
2. `_work/gitgraph.tl`'s `cmd_attach`: gains `repo`/`base` string
   parameters (both optional — "" means "use what the item already
   carries"), setting `it.repo`/`it.base` from them when non-empty
   BEFORE `problems(it)` runs, mirroring `cmd_new`'s existing `repo`
   parameter. An item already carrying `repo`/`base` (set at `new`
   time, or by a prior `gitboard set`) attaches with no flags needed;
   one with neither the flags nor existing values is refused by step
   1's gate, naming which field(s) are missing.
3. `_work/gitboard.tl`'s CLI dispatcher: wire `--repo OWNER/NAME` and
   `--base BRANCH` flags onto the `attach` verb, parsed and passed
   through exactly like `new`'s existing `--repo` (`_work/gitboard.tl:363`).
4. `cmd_new`'s existing behavior when called WITHOUT `--parent` (an
   unparented capture, filed into triage) is unchanged — a root
   legitimately carries no repo/base until it gains one via `attach`.
   `new --parent X` with no `--repo` now REFUSES via step 1's gate
   (today it silently succeeds with `repo = ""`); `--base` gains the
   same requirement, so `new --parent X --repo Y` alone (no `--base`)
   also refuses now — a caller of the parented form must state both.
5. `_work/brief.tl`'s `cmd_brief` (`_work/brief.tl:217-232`): remove
   the `master`/`main` guess-when-unset fallback for `BASE_BRANCH`.
   Once step 1 ships, no NEWLY parented item can reach `brief` with an
   empty `base` — but an item parented before this change may still
   carry one. For that item, `brief` should refuse outright (naming
   the missing field, same as `problems`'s own message) rather than
   guess, closing the exact incident above at its last remaining
   silent-default site rather than leaving it as a narrower window.
6. Tests (`_work/item_test.tl`, `_work/gitattach_test.tl`,
   `_work/brief_test.tl`): a root with empty repo/base still passes
   (unchanged); a root with either set still fails (unchanged); a
   non-root with either empty now fails, naming the missing field; `new
   --parent` with no `--repo`/`--base` refuses; `attach` with no
   flags and no pre-existing item repo/base refuses; `attach --repo
   --base` on a bare item succeeds and persists both; `attach` with no
   flags on an item that already carries repo/base (from `new --repo`
   or a prior `set`) succeeds unchanged; `brief builder` on a
   (synthetically constructed, pre-change-shaped) item with empty
   `base` refuses rather than guessing `main`/`master`.
