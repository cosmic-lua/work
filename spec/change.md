Two files on the `board` branch, landed as a PR whose base is
`board`; gate with `bin/cosmic --make ci` in the board worktree.

1. **`_work/gitboard.tl`** — the move dispatch resolves the mover
   unconditionally: `local mover = session.resolve(nil)` beside the
   existing claim fill (keep the to-do/to-check claim fill exactly as
   is), and passes `mover` to `cmd_move` as a new trailing parameter.
2. **`_work/gitverbs.tl`** — `cmd_move` gains `mover: string`. Before
   the `is_return` claim-clear, one guard:

   ```teal
   if flow.is_return(from, target) and from == "do"
   and (it.claim or "") ~= "" and it.claim ~= mover
   and (claim or "") == "" and not force then
     return gate.verdict_line("move", false,
       ("REFUSED: moving %s out of do abandons %s's live claim — the "
         .. "builder returns their own work; take over a dead "
         .. "session's with --force --why"):format(
         id:sub(1, 8), it.claim))
   end
   ```

   The `from == "do"` bound is the decision, recorded here: `do` is
   the one phase where a claim means work in progress on a machine
   the board cannot see; a claim on `check`/`land` marks the builder
   for review distance, and reviewer-driven leftward motion out of
   those phases already flows through `cmd_verdict`. The doc comment
   above the guard says exactly this. `cmd_set`'s `set_in_place`
   path (`:99`) is untouched — same-phase edits do not clear claims.
3. **`_work/gitverbs_test.tl`** — two tests in the file's existing
   fixture style: a `do -> ready` move of an item claimed by
   `session-A`, moved with mover `session-B` and no force, is refused
   naming session-A and `--force --why`; the same move with mover ==
   claimant succeeds and clears the claim (the bounce stays free).
   Follow how existing tests drive `cmd_move` and thread the new
   parameter through every existing call site in the test file.
