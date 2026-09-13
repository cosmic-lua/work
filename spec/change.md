Three files. Tree facts measured 2026-08-24 at `9bcb0f7d` (`git log
--oneline -1`) with the commands quoted beside each.

**1. `cosmic/searcher.tl`** — `wc -l cosmic/searcher.tl` is 404 (96
lines of headroom under the 500-line cap); `grep -c install_zip
cosmic/searcher.tl` is 0.

Add a module-local `zip_searcher(module_name)` and a public
`install_zip()`, exported through the `SearcherModule` record
(`cosmic/searcher.tl:392-404`, beside `install`,
`install_argv_manifest`, `install_manifest`).

- `zip_searcher(name)`: `local rel = (name:gsub("%.", "/"))`, then for
  `"/zip/" .. rel .. ".lua"` and `"/zip/" .. rel .. "/init.lua"` in
  that order, call `loadfile(path)`; on the first non-nil chunk return
  `chunk, path` (the loader plus its loader-data filename, the same
  pair the default file searcher returns). On a miss return `""` — the
  EMPTY string, deliberately: a searcher must return a string, and the
  `/zip` templates stay in `package.path` (Non-goals), so the default
  file searcher still contributes the `no file '/zip/…'` lines and
  `require`'s aggregate error text stays exactly what it is today. Say
  that in the doc comment, with the second consequence: `loadfile`
  returns `nil, err` for a SYNTAX error too, so a corrupt module reads
  as a miss here and is then found, loaded and reported properly by
  the default file searcher one seat later — the fallback is what
  keeps the error honest.
- `install_zip()`: no return value, idempotent via a module-local
  `zip_installed` flag, plain no-op when `package.searchers` is nil —
  the same shape and guard as `install` (`cosmic/searcher.tl:130-136`),
  so its record entry is `install_zip: function()`. It does two things:
  1. **Dedupe `package.path`.** Split on `;`, drop every occurrence
     after the first of exactly `/zip/?.lua` and of exactly
     `/zip/?/init.lua`, rejoin. Only those two templates, and only
     exact-equal fields — no general dedupe of the path.
  2. **Seat the searcher.** `table.insert(package.searchers, 2,
     zip_searcher)` — after `package.preload`, ahead of the default
     file searcher.

**2. `cmd/cosmic/main.tl`** — `wc -l cmd/cosmic/main.tl` is 498, i.e.
2 lines of headroom, so this edit MUST pay for itself (Acceptance has
the bound). Keep the `package.path` splice at lines 12–14 exactly as
it is: it is the bootstrap that lets line 25's `require("cosmic.
searcher")` resolve at all, and `install_zip()`'s dedupe cleans up the
duplicate it creates. Add, immediately after `local searcher =
require("cosmic.searcher")` (line 25) and BEFORE
`searcher.install_argv_manifest(arg)` (line 27), a call to
`searcher.install_zip()` with a short comment. Order is the point:
seating `/zip` first means `install_manifest`'s insert-at-2
(`cosmic/searcher.tl:361`) pushes `/zip` to seat 3, so `--modules`
tree resolution keeps outranking the binary's payload. To stay under
the cap, rewrite the 6-line comment block at lines 6–11 (which
explains the `/zip`-ahead-of-`/zip/.lua/` ordering that
`install_zip`'s own doc comment now owns) down to at most 2 lines; any
equivalent trim in this file is fine — the Acceptance `wc -l` bound is
the contract.

**3. `cosmic/embed/init.tl`** — `wc -l cosmic/embed/init.tl` is 459
(41 lines of headroom). In `WRAP_MAIN` (lines 179–184), the generated
entry wrapper every artifact carries, replace
`require("cosmic.searcher").install()` with:

```
local searcher = require("cosmic.searcher")
searcher.install_zip()
searcher.install()
```

Leave the `package.path` prepend at line 180 (the wrapper's own
bootstrap, before `cosmic.searcher` is reachable) and leave
`WRAP_SENTINEL` at line 174 byte-identical — the sentinel is the
idempotence test for extract/embed roundtrips
(`cosmic/embed/init.tl:243`). This is the half that pays: `o/bin/
cosmic` is itself wrapped (`_make/artifact.tl:465` embeds through
`cosmic.embed.write`), so the wrapper is where the ~15 boot modules
are resolved.

**Tests** (all three files already exist; each new test is called on
the line after its `end`, per AGENTS.md):

- `cosmic/searcher_test.tl` (`wc -l` 97): a test that after
  `install_zip()` the searcher at index 2 returns a function and the
  path `/zip/cosmic/json.lua` for `"cosmic.json"`; a test that a
  repeat `install_zip()` does not grow `#package.searchers` (the
  idempotence shape already used at `cosmic/searcher_test.tl:84-87`);
  and a test that a miss returns a string.
- `cosmic/searcher_tree_test.tl` (`wc -l` 284): extend
  `test_install_lands_ahead_of_the_file_searcher` (line 115) or add a
  sibling asserting `package.searchers[2]` is the TREE searcher after
  `install_manifest`, with the zip searcher demoted behind it.
- `cosmic/embed_test.tl` (`wc -l` 401): a child-process assertion that
  in a built artifact each of `/zip/?.lua` and `/zip/?/init.lua`
  appears EXACTLY ONCE in `package.path` (today it is twice — `grep -rn
  "/zip/?.lua" --include=*.tl .` outside `o/` returns exactly the two
  prepend sites, `cosmic/embed/init.tl:180` and `cmd/cosmic/main.tl:14`,
  and a wrapped binary runs both).
