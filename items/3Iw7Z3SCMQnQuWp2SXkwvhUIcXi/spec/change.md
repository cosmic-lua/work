Add a `--body-only` boolean flag to `gitboard brief` that suppresses
the trailing verdict line on the SUCCESS path only, so the command's
entire stdout is the agent-facing body — pasteable directly, no
post-processing.

- `_work/gitcommands.tl`, `brief`'s `flags` list (line 109): add
  `{long = "body-only", help = "print only the agent-facing body — no "
  .. "trailing verdict line — so the output can be captured straight "
  .. "into an agent prompt (e.g. `gitboard brief builder ID > out.txt`)"}`
  alongside `dir_flag()`.
- `_work/gitboard.tl:230-240`, the `brief` dispatch: pass the new
  switch through: `return brief.cmd_brief(s, d.parsed.args[1] or "",
  target, d.parsed.switches["body-only"])`.
- `_work/brief.tl`:
  - `cmd_brief`'s signature (declaration at line 341 and definition at
    line 241) gains a `body_only: boolean` parameter.
  - Every EARLY-RETURN refusal path (lines 244, 249, 253, 265, 272 —
    no handover recorded, CI still running/red, etc.) is unaffected:
    those emit no body at all, so they always print their verdict
    line regardless of `body_only`.
  - The SUCCESS path (currently lines 323-334): keep `print(body)`
    unconditionally. Replace the trailing `return gate.verdict_line(...)`
    with: when `body_only` is true, `return 0` with nothing further
    printed; otherwise the existing `gate.verdict_line(...)` call,
    unchanged.
- `_work/brief_rework_test.tl`: add one test case (not
  `_work/brief_test.tl` — see Evidence on its headroom) asserting that
  `cmd_brief(s, "builder", id, true)`'s captured stdout ends with the
  friction ask's own closing text (`brieftext_friction.ASK`'s last
  line) and contains no `gitboard-brief:` line, while
  `cmd_brief(s, "builder", id, false)` still ends with one — the
  existing `test_every_kind_prints_its_minted_claim_label`-style
  assertion (`_work/brief_test.tl:413`) is the pattern to mirror for
  the "false" half if a shared helper is convenient, called from the
  new file rather than duplicated into it.
- Update `brief`'s CLI help summary (`_work/gitcommands.tl:99-108`) to
  mention `--body-only` in the existing prose about the verdict line
  naming what's left to fill, so `gitboard brief --help` documents the
  flag's purpose alongside the flag's own one-line `help` text.

Gate with this repo's own test run over the touched files (however
this repo's CI invokes its test suite — `_work/brief_test.tl`,
`_work/brief_rework_test.tl`, and `_work/gitcommands.tl`'s own
CLI-spec tests if any name `brief`'s flag list).
