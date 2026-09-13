Not reverting `«nDWH_QNsm»` — the multi-line blindness it fixed is real
and its fix is strictly better than the behaviour before it. Not changing
`assert-justify`, `throw-justify` or `exit-justify`, which take the
single-line form and were verified not to share the defect. Not changing
the diagnostic's anchor line or the `_build/casts_kinds.tl` allowlist
path.
