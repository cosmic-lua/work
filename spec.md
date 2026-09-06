## Evidence

Measured 2026-09-06 during `/work 5 --routine` (friction log `Mbkg_EqvE`),
bootstrapped per `skills/work/SKILL.md`'s sibling-checkout path: a sibling
clone of `cosmic-lua/work` existed at `/home/user/work`, so the session set
`GITBOARD_DIR=/home/user/work` directly (a clone that is a SIBLING of the
product checkout `/home/user/cosmic`, not nested under it).

Running `bin/gitboard brief review <id>` from `/home/user/cosmic` under that
`GITBOARD_DIR` produced a verdict-recording block starting `cd /home` — not
`cd /home/user/cosmic`, the actual product checkout.

Root cause, `_work/brief.tl:227` (`product_root()`):

```lua
local function product_root(): string
  local dir = env.get("GITBOARD_DIR")
  if dir == nil or dir == "" then
    return ""
  end
  return fs.absolute_path(fs.dirname(fs.dirname(dir)))
end
```

This hardcodes the assumption `GITBOARD_DIR == "<product_root>/o/board"` (the
convention `bin/gitboard`'s own auto-export uses when no sibling exists, per
its doc comment two lines above: "`bin/gitboard` exports it as
`<root>/o/board`, so its parent's parent is the checkout root"). Under the
sibling-checkout bootstrap, `GITBOARD_DIR` is `/home/user/work` with no such
nesting at all, so `dirname(dirname("/home/user/work"))` = `/home` — two
directory levels short of the real product root, and silently wrong rather
than empty (which would at least leave `<PRODUCT_ROOT>` for the caller to
fill, the same way an unset `GITBOARD_DIR` already does per this function's
own doc comment).

This item's evidence is a single reproduction; the friction log names no
second occurrence, but the sibling-checkout path is the FIRST branch
`skills/work/SKILL.md`'s bootstrap block tries ("check for one before cloning
a second copy"), so any session that finds a sibling clone hits this on every
`brief review`/`brief builder` call that fills `<PRODUCT_ROOT>`.

## Change

Add an explicit override the bootstrap sets, rather than inferring the
product root from `GITBOARD_DIR`'s shape:

- `skills/work/SKILL.md`'s bootstrap block: export `GITBOARD_PRODUCT_ROOT`
  alongside `GITBOARD_DIR` in BOTH branches (the sibling-checkout branch and
  the fresh-`o/board`-clone branch) — `export GITBOARD_PRODUCT_ROOT="$(pwd)"`,
  the product checkout the session is bootstrapping from.
- `_work/brief.tl`, `product_root()`: read `GITBOARD_PRODUCT_ROOT` from the
  environment first; only fall back to today's
  `fs.absolute_path(fs.dirname(fs.dirname(dir)))` heuristic when that variable
  is unset or empty. Preserve the existing "" -> `<PRODUCT_ROOT>` left
  unfilled behavior when NEITHER is available.
- `_work/brief_test.tl`: a case setting `GITBOARD_PRODUCT_ROOT` to a value the
  parent-parent heuristic would NOT derive from the given `GITBOARD_DIR`,
  asserting the explicit value wins in the rendered brief.

## Non-goals

No change to the heuristic's behavior for a session that never sets
`GITBOARD_PRODUCT_ROOT` (the existing `<root>/o/board` convention keeps
working exactly as today, unchanged). No change to what `bin/gitboard`
itself auto-exports.
