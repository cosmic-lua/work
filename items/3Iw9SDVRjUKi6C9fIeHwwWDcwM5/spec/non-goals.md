- Not changing the cold-start path's behavior — `dirname(dirname($GITBOARD_DIR))`
  stays the first, unconditional attempt; this only adds a fallback
  for when it's wrong.
- Not changing `skills/work/SKILL.md`'s sibling-reuse bootstrap itself
  — exporting `GITBOARD_DIR` to the sibling's own root is the right
  shape for every OTHER verb (`sync`, `next`, `take`, etc. all read
  board state from `$GITBOARD_DIR` directly); only `brief`'s
  `PRODUCT_ROOT` derivation assumed a shape the sibling-reuse path
  never promised.
