- Do not change what `analyze` computes (`total` is still the static
  executable lines unioned with the lines actually hit) or how `render`
  formats a row. Both are what the committed `.cosmic-coverage` floor
  is expressed in.
- Do not lower any floor. `.cosmic-coverage` is expected to need no
  regeneration at all; see Acceptance for the bound if it does.
- Do not add an `init.tl` fallback to the `o/` branch, and do not
  exclude `o/stage/**` — re-measurement above shows neither case
  occurs. If a future run proves otherwise, that is a new item.
- Do not attempt the boot-load hit-loss hypothesis from the
  2026-08-21 note, and do not touch `cosmic/instrument.tl`.
- Do not chase the remaining coordinate-system mismatch: a chunk
  recorded against a `.tl` source directly (a script run through
  `--make run` in a tree that also holds a compiled `o/<script>.lua`)
  will parse the compiled file under the new rule. That case does not
  arise in this repo's coverage runs — all 32 distinct `.tl` chunk
  spellings in the run measured above sit under `o/.coverage/**`
  (`grep -rho '@[^"]*\.tl' o/.coverage | sort -u`) and every one of them
  is already dropped by `is_excluded`. Narrowing it further is a new
  item, not this diff.
- Do not remove `FileEntry.parse`, and do not touch
  `_tool/coverage/lines.tl` or `_tool/coverage/baseline.tl`.
