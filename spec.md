## Evidence

`«WyFa_GL3c»` (merged, PR #88) replaced `_work/brief.tl`'s old
whole-body regex placeholder scan with `survivors(template, values)`,
and removed `scan_values`'s special-cased blanking of
`BOUNCE_CONTEXT`/`ROUND_CONTEXT`, reasoning it was "now unnecessary"
since the new survivor check only reports names the template itself
declares. That reasoning covered the false-positive case (a
spec-quoted `<N>` never appearing in the template's own placeholder
set) but missed a second case the old blanking also handled: a
GENUINELY UNFILLED placeholder on a first-round pull.

Reproduced live, 2026-09-07, orchestrating a fresh wave from a
`cosmic-lua/cosmic` checkout (after bumping this repo's own stale
`bin/gitboard.pin` to the release carrying WyFa_GL3c, `2026-09-07-810ad91`
— the bug reproduces under the CURRENT fix, not a stale pin):

    bin/gitboard brief builder 3J0d5SYaJtSF4OYO3xaX4UyDCTW --out /tmp/brief.md
    # gitboard-brief: ... — fill <BOUNCE_CONTEXT>, then read it whole ...

Every builder brief for a FRESH pull (never reworked) now carries a
literal, unfilled `<BOUNCE_CONTEXT>` line, and the verdict line asks
the orchestrator to fill it — reproduced on two separate items pulled
in the same session (`X4Uy_DCTW`, `QwgY_FUPJ`), both first-round
pulls.

Root cause, `_work/brief.tl:417-421`:

```lua
if kind == "builder" then
  local bc = bounce_context(s, it)
  if bc ~= "" then
    values["BOUNCE_CONTEXT"] = bc
  end
end
```

When `bounce_context()` returns `""` (no prior round — the common
case, every fresh pull), `values["BOUNCE_CONTEXT"]` is never set at
all — left `nil`, not blanked to `""`. `fill()`'s `gsub` leaves a
placeholder untouched exactly when `values[key] == nil`, so the
literal `<BOUNCE_CONTEXT>` token survives into the rendered body. The
new `survivors()` then (correctly, per its own logic) reports it as a
real survivor, since `values["BOUNCE_CONTEXT"]` really is nil — this
is not a false positive in `survivors()` itself; the bug is one layer
up, in what `fill_values`/this call site puts into `values` for the
common no-bounce case.

This is a straightforward regression: before WyFa_GL3c, the deleted
special-case explicitly set `out["BOUNCE_CONTEXT"] = ""` for exactly
this case (confirmed via `git show <pre-WyFa_GL3c commit>:_work/brief.tl`
— the deleted `scan_values` blanking block), which made `<BOUNCE_CONTEXT>`
resolve to nothing (an empty line) rather than surviving.

## Change

`_work/brief.tl`'s builder-kind fill: when `bounce_context(s, it)`
returns `""`, set `values["BOUNCE_CONTEXT"] = ""` explicitly (restoring
the old blanking behavior for the no-bounce case), rather than leaving
the key absent from `values`. Do not restore the OLD mechanism
(scanning the whole rendered body) — only restore this one call site's
behavior for the empty-bounce-context case; `survivors()` itself
(the actual bug WyFa_GL3c fixed) stays as landed.

Add a regression test to whichever test file already covers
`fill_values`/builder-brief rendering (check `_work/brief_test.tl` and
`_work/brief_review_script_test.tl` — the file-cap latitude from
`«RXhD_TRHL»` applies if the natural home is at its cap) asserting: a
FRESH (non-rework) builder brief's rendered body contains no literal
`<BOUNCE_CONTEXT>` token, and its verdict line does not name
`BOUNCE_CONTEXT` as a survivor.

## Non-goals

Not touching `ROUND_CONTEXT`'s handling — confirm whether it has the
same bug (a symmetrical code path) as part of this item's own
investigation; if it does, fix both in the same change since they are
the same shape and the spec-bar prefers one mechanism, not two. Not
reverting or altering `survivors()` itself — it is working exactly as
designed; the bug is purely in what `values` is populated with.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
