- No change to claim LOCKING: `set_in_place`, `cmd_move`'s takeover
  guard, and every draw (`unheld`, `refinable`, `pullables`) compare
  exact strings — an orchestrator's own `next` still sees its agents'
  claims as held, which is correct (they ARE held, by its wave).
- No change to `session.resolve` or the identity ladder.
- No edit to skills/work/loop.md on `main`: its minted-identity form
  and verdict wall stand; this is the machinery half it names.
- No migration of existing items: no recorded name carries `/` today
  (`grep -l '"claim"] = ".*/' items/*.tl` is empty, measured now).
