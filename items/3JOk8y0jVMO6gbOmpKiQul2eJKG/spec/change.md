`_work/stateclaim.tl` exports a function `authority`. `_work/stateclaim_authority.tl`
is a different module, exporting `authority.current` and `authority.historical`,
testing worktree receipt validation. They sit in the same directory, share a
name, and test entirely different things. `_work/stateclaim_authority_test.tl`
tests the MODULE and never imports `_work/stateclaim`.

Rename one side so the collision cannot mislead a reader again. Two options,
and whoever takes this picks with reasons:

- rename the FUNCTION in `_work/stateclaim.tl` to say what it renders — it
  produces the current-claim report, so `claim_report`, `render_authority` or
  similar; its callers are few (`_work/snapshot_publish.tl` and the tests);
- or rename the MODULE `_work/stateclaim_authority.tl` to say what it
  validates — receipt authority, not claim rendering.

Renaming the function is the smaller diff and leaves the module name, which is
the more descriptive of the two, alone. Check the callers before deciding.

Whichever is chosen, move or rename nothing else, and update the sibling test
file name to match if the module is the side that moves.
