Not reverting `«#1797»` — per-file AST classification is the right
direction and the allowlist behaviour it added is unaffected. Not changing
`_build/casts_kinds.tl`, `assert-justify` or `throw-justify` unless they
share the same helper and the same defect, in which case say so and fix it
once. Not relocating any justification comment in cosmic's own tree to
work around this.
