Extend the rule to cover all three — no exclusions needed. Verified end
to end against a fresh clone, cold build (`make -j$(nproc)
o//tool/lua/test`) and the real `o//tool/lua/lua.dbg` interpreter:

- **`dbdata`**: its marker lives under `ext/recover/`, not `ext/misc/` —
  add a `MARKER_DIR` override table (parallel to batch 2's
  `MARKER_STEM`), keyed per unit, defaulting to `ext/misc/`.
- **`dbdata`**: its commented linkage include names `sqlite3.h`, not
  `sqlite3ext.h` (`dbdata.c` guards its prelude on
  `#if !defined(SQLITEINT_H)` so it can also compile inside the
  amalgamation, and its init never touches
  `SQLITE_EXTENSION_INIT2`/the extension API) — add an `INCLUDE_HEADER`
  override table, one entry (`dbdata = "sqlite3.h"`), default
  `"sqlite3ext.h"` for everything else. **Not** a blanket
  "capture whatever header name the comment names" generalization:
  `fileio.c`'s shell.c section (already landed) also carries an
  unrelated commented `/* #  include "windirent.h" */`
  (shell.c:9820, Windows-only, deliberately never restored) that a
  blanket capture would wrongly try to substitute, breaking the
  currently-green `fileio` extraction.
- **`dbdata`**: two adjacent commented typedef stand-ins
  (`u8` then `u32`, shell.c:19779-19780, one newline apart) expose a
  pre-existing bug in the typedef-restoration rule: its single-pass
  `gsub` consumes the shared newline restoring the first, so the
  second's required leading `\n` is gone and it is never restored
  (confirmed: `gcc -fsyntax-only` on the naively-extracted file fails
  `unknown type name 'u32'`). Loop the typedef-restore `gsub` to a
  fixpoint (`repeat ... until n == 0`). No already-landed unit has two
  typedef-comments this close together, so this is a latent, rule-wide
  bug `dbdata` is the first unit to trigger, not a `dbdata`-only fix.
- **`base64`/`base85`**: `SQLITE_SHELL_EXTFUNCS` is never `-D`'d
  anywhere in this repo (confirmed: zero hits outside shell.c itself,
  and no `BUILD.mk` flag set defines it), so the `#ifndef
  SQLITE_SHELL_EXTFUNCS` (first, non-`static`) branch is always the
  live one in the compiled shell binary, and the ONLY one usable by the
  registry — `extensions.c` is a separate translation unit and cannot
  call a `static` symbol from the `#else` branch. This inverts the
  original candidate framing ("extract only the `#else` branch if it's
  the registry-legal shape"): the `#else static int` branch is the dead
  one. Fix: loosen the test's definition check from an exact literal
  match to a non-greedy pattern, `"\nint " .. inits[i] .. ".-%("` —
  still matches every already-landed unit's plain one-line definition
  unchanged, and now also matches the name landing on its own
  declaration line ahead of `#else`/`#endif`.
- **`base85`**: independently, its commented linkage include is
  `/* # include "sqlite3ext.h" */` (shell.c:7102, note the space after
  `#`) where every other unit (including `base64`) has
  `/* #include "sqlite3ext.h" */` (no space) — the test's
  `INCLUDE_INLINED` literal-string match finds zero matches, failing
  the test's own `assert(n == 1, ...)` before the definition check is
  ever reached. Generalize the include-restore pattern to tolerate
  optional whitespace (`#%s*include`), scoped to the specific header
  name being looked up (paired with the `INCLUDE_HEADER` override
  above, not a blanket "any header" capture, for the same `fileio`
  reason as above).

Once landed, all five units wire in the same way batches 2 and 3 did:
`THIRD_PARTY_SQLITE3_A_SRCS`/`_OBJS`, `extensions.h` inits, registry +
alias entries, size delta reported, green on
`make -j$(nproc) o//tool/lua/test`.
