`_work/brieftext.tl`, the BUILDER template's push/PR steps (the
"Open a PR from" step, `grep -n 'Open a PR' _work/brieftext.tl`): add
one sentence after the READY/not-draft instruction — "Open it with
whatever GitHub reach the session has: the `gh` CLI when present,
otherwise the GitHub MCP tools (`mcp__github__create_pull_request`,
loaded with ToolSearch); the Board: line is the body's first line
either way." Add a second sentence to the same step: "Never poll or
subscribe to GitHub events (no `subscribe_pr_activity`, no re-check
loops) — CI and review are the orchestrator's to watch; report and
end."

`_work/brieftext_review.tl`, the "Recording your verdict" section's
`accept` bullet where auto-merge is enabled: the same mechanism
sentence, naming `mcp__github__enable_pr_auto_merge` as the MCP
equivalent.

`_work/brieftext_test.tl` (57 lines): one case asserting the rendered
builder brief contains `mcp__github__create_pull_request` and the
review brief contains `mcp__github__enable_pr_auto_merge`.
