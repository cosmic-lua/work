In `cosmic/embed/init.tl`'s embed policy (near the `is_lua` local
around lines 394-397), keep the current per-entry method decision but
narrow the "store" branch from "every `.lua` entry" to "every `.lua`
entry in the measured boot set", deflating everything else including
the rest of the `.lua` corpus.

The measured boot set (from `plaA_uCdm`'s evidence, `./cosmic-lua -e
'for k in pairs(package.loaded) do print(k) end'` against a bare boot,
cross-referenced against `/zip`-resolved modules): 16 modules summing
54,816 bytes — `main`, `_cli.args`, `_cli.main_handlers`,
`_cli.require_hints`, `_cli.run`, `cosmic._fields`, `cosmic.env`,
`cosmic.errno`, `cosmic.flags` (and its submodules), `cosmic.
instrument`, `cosmic.searcher`, `cosmic.tty`. Re-measure this set
against the current tree rather than assuming the list is unchanged
since 2026-08-29 — module boundaries may have shifted.

The two heavyweight entries that drove the original size win
(`.docs/index.lua`, `tl.lua`) are NOT in the boot set (they load only
on `--docs` and type-check paths) — they deflate under this policy,
recovering most of the original ~2.0MB claim without the startup cost.
