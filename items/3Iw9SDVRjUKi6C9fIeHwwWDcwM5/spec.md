## Evidence

`_work/brief.tl:226-232`'s `product_root()` fills a review brief's
`PRODUCT_ROOT` (used in the verdict-recording block's `cd <path>`
line) by computing `dirname(dirname($GITBOARD_DIR))`:

```
local function product_root(): string
  local dir = env.get("GITBOARD_DIR")
  if dir == nil or dir == "" then
    return ""
  end
  return fs.absolute_path(fs.dirname(fs.dirname(dir)))
end
```

documented as correct because "`bin/gitboard` exports it as
`<root>/o/board`, so its parent's parent is the checkout root." That
holds for the COLD-START bootstrap path
(`skills/work/SKILL.md`'s bootstrap section, the `else` branch:
`git clone https://github.com/cosmic-lua/work o/board`, and
`bin/gitboard` exports `GITBOARD_DIR=o/board` itself).

It does NOT hold for the documented SIBLING-REUSE path, in the same
skill file:

    sibling="$(cd .. 2>/dev/null && cd work 2>/dev/null && pwd)"
    if [ -n "${sibling}" ] && git -C "${sibling}" remote get-url origin 2>/dev/null | grep -q cosmic-lua/work; then
      export GITBOARD_DIR="${sibling}"          # reuse it, no clone needed
    ...

Here `$GITBOARD_DIR` is the sibling clone's OWN root (e.g.
`/home/user/work`), not `<checkout-root>/o/board`. Reproduced directly,
2026-09-06, in a session bootstrapped exactly this way:

    $ GITBOARD_DIR=/home/user/work bin/gitboard brief review <ID> | grep '^cd '
    cd /home

(`dirname(dirname("/home/user/work"))` = `/home`, which has no
`bin/gitboard` in this environment — the real checkouts are
`/home/user/cosmic` and `/home/user/cosmopolitan`.) Every review brief
emitted in a sibling-reuse session carries this same broken `cd` line
in its verdict-recording block — the review agent's actual review work
completes normally, but the LAST step (recording the verdict) fails
immediately on `cd /home && bin/gitboard ...: bin/gitboard: No such
file or directory`, discovered only when the agent runs it, not when
the brief is emitted.

## Change

`_work/brief.tl`'s `product_root()`: when `dirname(dirname($GITBOARD_DIR))`
does not contain a `bin/gitboard` file (`fs.is_file(candidate ..
"/bin/gitboard")`), it is not a real product checkout — fall back to
searching upward from the CURRENT WORKING DIRECTORY (the orchestrator's
own checkout, which is always a real product repo — that's what
`bin/gitboard` was invoked from) for the nearest ancestor directory
containing `bin/gitboard`, the same way a project root is normally
found. Return `""` (today's already-handled "leave `<PRODUCT_ROOT>`
for the caller to fill" case) only if neither the dirname-dirname
guess nor the cwd search finds one.

Keep the existing dirname-dirname computation as the FIRST attempt
(cheap, correct for the common cold-start case) — this is an added
fallback, not a replacement.

`_work/brief_test.tl` or `_work/brief_rework_test.tl` (check current
headroom in each — `brief_test.tl` was at 498 lines as of 2026-09-06,
prefer `brief_rework_test.tl` if it's tighter): add one test setting
`GITBOARD_DIR` to a sibling-shaped path (not ending in `o/board`) with
a real `bin/gitboard` reachable only via the cwd fallback, asserting
the emitted brief's `PRODUCT_ROOT` resolves to the real checkout, not
the wrong dirname-dirname guess.

## Non-goals

- Not changing the cold-start path's behavior — `dirname(dirname($GITBOARD_DIR))`
  stays the first, unconditional attempt; this only adds a fallback
  for when it's wrong.
- Not changing `skills/work/SKILL.md`'s sibling-reuse bootstrap itself
  — exporting `GITBOARD_DIR` to the sibling's own root is the right
  shape for every OTHER verb (`sync`, `next`, `take`, etc. all read
  board state from `$GITBOARD_DIR` directly); only `brief`'s
  `PRODUCT_ROOT` derivation assumed a shape the sibling-reuse path
  never promised.
