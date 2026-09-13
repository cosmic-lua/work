- No change to `unix.sigaction` or its annotation.
- No new test target for the demos.

The demo is embedded into `o//tool/net/redbean-demo` (`tool/net/BUILD.mk`,
`TOOL_NET_COMS`), so the tree ships a binary whose demo raises on its
restore path; no gate executes it, hence green CI (confirmed by #338's
review on the merged binary:
`pcall(u.sigaction, u.SIGINT, old)` → `false, bad argument #2 ...`).
