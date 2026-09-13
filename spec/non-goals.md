Not a tool-level guard (e.g. `take` refusing a bare, un-prefixed
session id) — that would need to distinguish a legitimate solo
session's own bare-session claim (fine; it holds one item and drops
it before pulling another, same as `--session` would) from an
orchestrator's, which the tool cannot tell apart. Doc-level fix only.
