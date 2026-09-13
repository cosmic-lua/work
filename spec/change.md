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
