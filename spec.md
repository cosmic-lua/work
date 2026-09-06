## Evidence

The builder and review briefs tell an agent to push and "open a PR" /
"enable auto-merge" but name no mechanism. In the remote sessions that
run these agents there is no `gh` CLI (`which gh` → nothing; the
session's own system prompt says "You do NOT have access to the gh CLI"
and to use the GitHub MCP tools instead), and outbound HTTPS is a
proxy that needs `SSL_USE_SYSTEM_CERTS=1`, which the brief already
states. Two passes hit the gap: «KGOw_xnx8» (2026-09-05, review brief
assumed `gh`), and 2026-09-06 work4, where the orchestrator appended
the same environment paragraph by hand to all six builder prompts:

    Environment: this session has no gh CLI; open the PR with the
    GitHub MCP tools (mcp__github__create_pull_request; use ToolSearch
    to load it). Never poll or subscribe to GitHub events; report and end.

`grep -n 'gh \|MCP' _work/brieftext.tl _work/brieftext_review.tl` →
only the SSL_USE_SYSTEM_CERTS lines; no PR-opening mechanism anywhere.

## Change

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

## Non-goals

No change to the RESEARCH/REFINE/DECOMPOSE templates (they open no PR).
Not the request-changes delivery mechanism — that is «IB9Z_CwM4».
