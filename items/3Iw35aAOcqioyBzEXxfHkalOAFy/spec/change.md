**Unblocked, 2026-09-06 (orchestrator re-measure).** Both preconditions
the bounce named now hold on `main`, verified against the tree, not
inferred:

- The `_types/gentype_defs.tl` circularity is gone: it reads
  `definitions.lua` through the raw binding, not the wrapper.
  `git log -1 --format='%h %s' -- _types/gentype_defs.tl` →
  `bce2348 gentype_defs: break cosmic/zip.tl out of the zip
  type-generation bootstrap (#1747)`; `grep -n 'require' _types/gentype_defs.tl`
  → `8:local fs = require("cosmic.fs")` / `14:local zip = require("cosmo.zip")`
  and no `cosmic.zip` line. No separate circularity item is needed.
- The pin already names a release carrying `zip.reader`:
  `grep version 3p/cosmos/cosmos_pin.tl` → `version = "2026.09.06-e748d6a1e"`,
  and in a cosmic-lua/cosmopolitan checkout `git merge-base --is-ancestor
  77a16357c44e4ee5332ebbd409e08980b91affc7 2026.09.06-e748d6a1e` exits 0
  (`e748d6a1e` is master's head; `77a16357c` is #389, `zip.reader`).

Ready when: `grep -c 'reader' o/_types/types_gen/cosmo/zip.d.tl` prints a
number ≥ 1 after `bin/cosmic --make fetch && bin/cosmic --make build`
(the generated declaration carries `zip.reader`). If it prints 0, the
pin regressed — drop bare.

Once ready:

- `3p/cosmos/cosmos_pin.tl`: bump to the qualifying release, if not
  already there when this is picked up.
- `cosmic/zip.tl:222`: change `handle, err = zip.open(path, "r",
  raw_opts)` / `zip.open(path, "r")` (lines 215-217) to call
  `zip.reader` instead — `zip.reader(path, raw_opts)` when `raw_opts`
  is set, `zip.reader(path)` otherwise, matching `zip.create`'s own
  call shape immediately below it (line 225). Delete the `-- cast:
  from any` comment and the `as zip.Reader` cast at line 222; `handle`
  is now already typed `zip.Reader?` directly.
- `_build/casts_baseline.tl` / `docs/design/cast-sites.tsv` /
  `docs/design/casts.md`: regenerate and reconcile per this repo's
  standard cast-closing procedure (`bin/cosmic --make run
  _build/casts.tl --baseline`, `bin/cosmic --make run
  _build/cast_sites.tl --reconcile`), and update whichever class
  section in `casts.md` currently documents this site.
- `bin/cosmic --make ci` ends `ci: PASS` on a COLD build (`rm -rf o`
  first) — a converged/incremental-only green is not sufficient
  evidence here, since that is exactly what this bounce's own failure
  hid.
