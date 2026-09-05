## Evidence

`gitboard brief review <ID>` and `gitboard brief builder <ID>` both emit
a "Recording your verdict" / push section that tells the agent:

```
cd /home
export SSL_USE_SYSTEM_CERTS=1
bin/gitboard verdict ... --session <label>
```

`bin/gitboard` does not live at `/home` — it lives inside the product
checkout (in this environment, `/home/user/cosmic/bin/gitboard`), so a
literal `cd /home && bin/gitboard ...` fails with "no such file or
directory." Confirmed independently by two different fresh-context
review agents this pass, on two different PRs:

- reviewer for board item `1Lhz_38Wt` / PR #1727 (subagent `aaf38f06`):
  "first tried `GITBOARD_DIR`-relative `bin/gitboard`... the binary
  lives in the product checkout's `bin/`, not the board checkout's" —
  cost one failed call.
- reviewer for board item `EAi9_RFmX` / PR #1729 (subagent `a0089c5`):
  "I first tried `cd /home && bin/gitboard ...` per the literal
  instructions, which failed (no such file)... it actually needs
  `cd /home/user/cosmic` (or wherever the product checkout is)" —
  cost one extra find/ls round trip.

Both recovered in one extra tool call each, so the per-incident cost is
small, but it is now 2/2 independent fresh-context agents this single
pass hitting the identical wrong turn from the identical brief text —
not a one-off misreading.

**Likely NOT the same bug `TE1u_Un2i` (PR #34) and `U7bX_uuKQ` (PR #37)
already fixed and merged** — those replaced a stale `cd <BOARD_DIR>; \
o/bin/gitboard verdict` with `cd <PRODUCT_ROOT>; bin/gitboard verdict`.
The text this session actually received from `gitboard brief review`
this pass already uses the POST-fix form (`bin/gitboard`, not
`o/bin/gitboard`) — but `<PRODUCT_ROOT>` itself resolved to the literal
string `/home`, not the actual product checkout path
(`/home/user/cosmic` in this environment). So the remaining bug looks
like it is in HOW `<PRODUCT_ROOT>` gets resolved/substituted for a
checkout nested one level deeper than whatever the substitution logic
assumes (e.g. `/home/<user>` vs. this environment's
`/home/user/<repo>`), not the already-fixed template text itself.

## The question

Where does `gitboard brief`'s template text live (the source this
session did not locate — outside the three repos this session has
GitHub access to, cosmic-lua/cosmic, cosmic-lua/cosmopolitan, and
cosmic-lua/work, or inside cosmic-lua/work's own tool source but not
found by this session's search)? Whoever has that access should either:
(a) have the brief derive the actual product-checkout path per
environment instead of hard-coding `/home`, or (b) reword the
instruction to say "the product checkout, wherever it is" and let the
agent find it, rather than asserting a specific wrong path. This item
is filed as a captured finding rather than a ready-to-pull spec because
this session could not locate the template's source to write the exact
`## Change`.
