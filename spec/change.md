`_build/doc_paths_test.tl` (runner mode): for every `docs/**/*.md`
and `skills/**/*.md`, every backtick span that looks like a repo path
with a known extension (`.md .tl .lua .mk .yml .sh`) and contains a
`/` must name a file or directory in the tree, or match an explicit
allowlist in the test of pattern-shaped spans (globs, `o/` outputs,
`<name>` placeholders). Fail naming file:line and the missing path.
The first run's report is this PR's fix list: correct each stale
reference in place (prose only) or allowlist it with a one-line
reason; the allowlist starts as small as the measured run allows.
