## Evidence

`gitboard brief KIND ID` prints two things to stdout, unconditionally,
in this order (`_work/brief.tl:323-334`):

    local body = fill(template, values) .. "\n\n" .. brieftext_friction.ASK
    print(body)
    ...
    return gate.verdict_line("brief",
      true, ("%s brief for %s, claim it as %s — %s"):format(
        kind, tail.handle(it.id), label, tail_note))

`gate.verdict_line` (`_work/gitgate.tl:31-37`) always `print`s its
line — there is no separate stream to redirect around it:

    local function verdict_line(verb: string, ok: boolean, detail: string): integer
      print(("gitboard-%s: %s"):format(verb, detail))
      ...

So `gitboard brief builder ID > out.txt` captures the agent-facing
body AND a trailing `gitboard-brief: builder brief for «ID», claim it
as ..., — fill <WORKTREE>, ..., then paste the body verbatim` line in
the same file. That trailer is orchestrator-facing (which placeholders
still need filling, what session string to claim under) — it is not
part of what a spawned builder agent should see, but nothing distinguishes
it from the body in the command's output.

Observed cost, from an orchestrator pass on 2026-09-06 briefing 6
items: every one of the 6 brief captures needed a manual post-process
step (`sed -i '$ d'` on each file) to strip the trailing line before
pasting the body into a builder agent's prompt — one extra shell call
per item, run once per brief regardless of item count.

`brief`'s own CLI spec currently has no flag beyond `--dir`
(`_work/gitcommands.tl:96-109`):

    {name = "brief", summary = "print KIND's subagent prompt for ID, "
      .. "board facts filled",
      spec = {usage = "KIND ID [options]",
        ...
        flags = {dir_flag()}}},

Its dispatch (`_work/gitboard.tl:230-240`) passes only `kind` and the
resolved `id` through to `cmd_brief`:

    if d.command == "brief" then
      ...
      return brief.cmd_brief(s, d.parsed.args[1] or "", target)
    end

A boolean switch is read elsewhere via `d.parsed.switches["<name>"]`
(worked pattern, `_work/gitboard.tl:320-322`, `take`'s `--force`):

    return verbs.cmd_take(s, id, who, pr,
      d.parsed.switches["force"], d.parsed.values["why"] or "",
      d.parsed.switches["result"])

`_work/brief_test.tl` is 498 lines (`wc -l`); a new test case there
risks the same near-cap collision this repo's own spec-bar doctrine
(`gitboard help bar`, "sizing") warns against. `_work/brief_rework_test.tl`
(195 lines, `wc -l`) covers the same `cmd_brief` surface and has
headroom.

## Change

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

## Non-goals

- Not changing `verdict_line`'s signature or behavior for any other
  verb — the fix is local to `brief`'s success path, not a stream
  change (stdout vs. stderr) applied globally.
- Not suppressing a REFUSAL's verdict line under `--body-only` — a
  refusal has no body to separate it from, so it always prints.
- Not changing what `unfilled(scan_body)` reports or how `tail_note`
  is worded — `--body-only` only decides whether that line prints, not
  what it says when it does.
