## Change

Two files and one flag: `_tool/surface.tl`, the extractor of a tree's
name-level public surface, and `cosmic --diff OLD`, which prints the
running binary's surface against another binary's. The extractor is
the one reader both the ratchet (sibling item) and the upgrade verb
(sibling item) consume, so it lands first and alone.

**`_tool/surface.tl`** (new; `_tool/` is embedded in the binary through
the import closure, never in user artifacts — `cmd/cosmic/embed_gen.tl`
ships every `module`-kind `.tl` in `artifact.scope_of`, measured at
`sed -n 198,206p cmd/cosmic/embed_gen.tl`). Interface:

```
record Surface
  --- key -> type string. Key grammar, four segments joined by ".":
  --- "cosmic.<module>.<Record>.<field>" for a record field,
  --- "cosmic.<module>.<Enum>.<member>" for an enum member (value "enum").
  entries: {string: string}
  --- the public modules seen, sorted, for the module-level view
  modules: {string}
end
--- sources: relative path -> Teal source, for every .tl under cosmic/
extract: function(sources: {string: string}): Surface
diff: function(old: Surface, new: Surface): {Delta}   -- sorted by key
record Delta  key: string  kind: string  -- "removed" | "added" | "retyped" | "module-removed" | "module-added"
              old: string | nil  new: string | nil  end
render: function(deltas: {Delta}): string          -- the text --diff prints
```

Rules `extract` applies, each one already decided elsewhere:

- A public module is exactly what `cosmic/doc/visibility.tl`'s
  `is_public` says (`cosmic.<leaf>`, leaf not starting with `_`;
  measured at `sed -n 27,33p cosmic/doc/visibility.tl`). A deeper path
  is a shard of its directory module — `cosmic/fs/path.tl` contributes
  to `cosmic.fs` — the same merge `_tool/doc/index.tl`'s
  `flatten_shards` makes for the doc pages. Files named `*_test.tl`,
  `*_example.tl` and underscore modules contribute nothing.
- Records and enums are read with the lexer, not a regex: `tl.lex`
  (`o/_types/types_gen/tl.d.tl:78`, `function(string, string): {Token},
  {Error}`), tokens carrying `y`, `x`, `tk`, `kind`. A `record`/`enum`
  block opens at the keyword (top-level `local record X` and nested
  `record X` alike — the tree has 314 top-level and 30 nested,
  measured with `grep -c '^local record\|^local enum'` and
  `grep -h '^  record \|^  enum '` over `cosmic/**.tl` minus tests and
  examples) and closes at its matching `end`; a field is `name :
  type` up to the end of line, the type reassembled from tokens with
  single spaces so formatting never reads as a retype; a trailing `--`
  comment is dropped (today's regex extractor mis-reports
  `Capabilities.net_ns`, whose comment changed, as a retype).
- Names are qualified by the module, not the file: `cosmic.fs.
  FsFileModule.write` whichever shard declares it.

**`cosmic --diff OLD`**: `_cli/args.tl` gains
`{long = "diff", arg = "BINARY", help = "public API of this binary against BINARY"}`
(the spec is 164 lines). The handler is `_cli/upgrade.tl`'s `diff(old:
string): integer` — the sibling `--upgrade` item adds to the same
file, so create it here with this one function. It opens both zips
with `cosmic.zip.open` (`cosmic/zip.tl:387`), OLD from the argument and
itself from `arg[-1]` (the interpreter path; the idiom
`cosmic/sandbox/init_example.tl:11` already uses), lists `.tl/cosmic/**`
(`Archive.list`, `Archive.read`, `cosmic/zip.tl:64,68`), extracts both
surfaces, prints `render(diff(old, new))`, exits 1 when any delta is
`removed`, `retyped` or `module-removed`, else 0. Output shape, one
module per block, deltas sorted:

```
cosmic.hash
  - HashModule.digest_hex: function(algo: Algo, data: string): string
  + HashModule.hex_digest: function(data: string, algo: Algo): string
cosmic.string
  ~ StringModule.shell_quote: function(s: string): string
    now function(s: string): string | nil, string
- module cosmic.uuid
diff: 3 removed or retyped, 2 added   (verdict line, survives truncation)
```

Dispatch: `cmd/cosmic/main.tl` is at the file cap (`wc -l` → 499), so
the one dispatch line — `if opts.diff then return
require("_cli.upgrade").diff(opts.diff) end` beside the `opts.version`
line at 336 — needs one line reclaimed: fold the two identical
env-fallback blocks at 328–335 (`COSMIC_OUTPUT`, `COSMIC_EXTRACT`) into
one two-line loop over `{{"COSMIC_OUTPUT","output"},{"COSMIC_EXTRACT","extract"}}`.
Add the flag to `sys/help.md` (76 lines) after `--docs`.

Tests: `_tool/surface_test.tl` with a fixture tree in `TEST_TMPDIR`
holding one plain module with an interface record and an `Options`
record, one directory module with a shard declaring a nested record,
an enum, an underscore module, and a test file; assert the exact
`entries` set, that a comment change is not a delta, and that the
type string is whitespace-normalized. `_cli/upgrade_test.tl`: build
two tiny zips with `cosmic.zip` carrying `.tl/cosmic/x.tl` variants and
assert `--diff`'s rendered text and exit codes for removed, retyped,
added-only, and module-removed.

## Non-goals

No baseline, no gate, no scan of a consumer's sources here. `--diff`
reads two binaries and nothing else; it does not touch the network or
the project.
