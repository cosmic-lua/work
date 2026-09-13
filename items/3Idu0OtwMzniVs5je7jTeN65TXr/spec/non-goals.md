- No binding change. `cosmo.DecodeJson`/`EncodeJson`/`EncodeLua` and
  their error strings are frozen; a corpus case that now disagrees with
  the fork's behavior is evidence for a *different* item, never a
  reason to edit `tool/net/definitions.lua` or the C here.
- Do not touch `test/tool/net/**` or `test/tool/BUILD.mk`. Retirement of
  the old lane is `3IOCgtWA`, blocked on the whole salvage container.
- Do not merge the 9 files into one. Each stays a direct, diffable copy
  of its origin under its own stamp.
- Do not re-run or re-measure the parent's pass/fail split; that
  evidence is settled in `3INxo51I`.
