`AGENTS.md`'s "versioned deps" bullet (under "Build System" → key concepts) gets
one added sentence documenting the verified incantation for forcing a patched 3p
target to be genuinely re-derived from its pin: `rm -rf o/3p/<name>` (e.g.
`o/3p/tl`) followed by `bin/cosmic --make fetch`, needed whenever verifying that a
`3p/*/tl_patch/*.tl` edit (add, change, or revert) actually took effect — a plain
`--make build`/`--make test` silently reuses the already-unpacked, already-patched
artifact and will not detect the source change on its own.
