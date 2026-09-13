Not a change to the merge mechanics themselves (`gitboard verdict`,
`done`, or the actual merge tool calls) — the fix is entirely in what
the emitted brief TELLS the reviewer to do; the orchestrator's own
landing step (calling the merge tool once accept is recorded) is
unaffected. Not a change to `_work/doctrine.tl`, which already states
the correct rule.
