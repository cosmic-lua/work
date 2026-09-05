## Evidence

`_build/doc_paths_test.tl` holds every backtick PATH in the prose to a file that exists.
No gate does the same for a backtick SYMBOL: `cosmic.fs_walk.walk` in a guide reads as
authoritative long after the module was renamed, and a reader who pastes it gets
`module not found`. The doc index is the symbol table the gate needs, and it already
ships: `cosmic.doc.embedded_index()` returns every module with its functions, records,
record fields and examples.

Measured 2026-09-05 at c39fc2f, over the 95 markdown files under `docs/`, `skills/`,
`README.md` and `AGENTS.md`, every backtick span shaped `cosmic.<mod>.<sym>` (a call
suffix stripped, fences skipped), resolved against `o/bin/cosmic`'s embedded index
(module, function, record, record field, example, or `module.Record.field`):

```
95 markdown files; 31 cosmic.<mod>.<sym> spans; 14 unresolved against the doc index
    5 docs/agent-usability.md          (a dated study — names the tree of its day, says so)
    4 docs/design/make/log/phase3-dogfood.md   (design log — same)
    2 docs/design/make/phasing.md      (cosmic._make.pin, cosmic.mk.lint.got — not symbols)
    1 docs/decisions/d24-structured-failures.md   cosmic.errors.Failure
    1 docs/decisions/d19-toolchain-visibility.md  cosmic.coverage.baseline (a retired module, by design)
    1 AGENTS.md:129                    cosmic.errors.Failure
```

`cosmic.errors.Failure` is live and correct prose that the index cannot answer:
`cosmic/errors.tl:23` declares it as `local interface Failure`, and `_tool/doc/init.tl`
extracts `local record` only (`init.tl:243`, `source:gmatch("()local%s+record%s+([%w_]+)")`):

```
$ o/bin/cosmic --docs cosmic.errors | grep -c "^## Failure"
0
$ o/bin/cosmic --docs cosmic.errors.Failure
Search results for 'cosmic.errors.Failure':
                                   (empty)
```

So the gate has one extractor gap to close first, and the two history exemptions
`doc_paths_test.tl` already declares (`HISTORY`) cover the dated documents here too.

Dotted spans that are NOT `cosmic.` (`_make.pin`, `fs.read` bare) are out of this
gate's shape: `fs.read` is unresolvable without knowing which `fs` the sentence means.
`cosmic.<mod>.<sym>` is exactly the form `--docs` accepts, which is what makes it
checkable.

## Change

1. `_tool/doc/init.tl`: the record extractor also takes `local interface <Name>`
   (same body scan, `find_record_end`), recorded as a `RecordDoc` with the description
   and fields it has; `--docs cosmic.errors.Failure` then answers. Test in
   `_tool/doc/init_test.tl`: an interface with a doc comment and one method field
   lands in `records`.
2. `_build/doc_symbols_test.tl` (new; the shape of `_build/doc_paths_test.tl`:
   `ROOTS`, `spans_of` with fence tracking, three excuse lists, a `--- reads:` header
   naming `docs skills README.md AGENTS.md` and `cmd/cosmic/embed_gen.tl`'s index
   output). The index is read from the tree's own build — `o/embed/cosmic/.docs/
   index.lua` — not `/zip`, so the test judges this tree, never the binary that runs
   it: declare the path in the `reads:` line so a rebuilt index re-runs the test.
   - A span is a symbol reference when it matches `^cosmic%.[%w_]+[%.:][%w_]+` and
     holds no space, `<`, or `*`; a trailing `(...)` is stripped.
   - It resolves when the index carries: the whole span as a module name; or
     `<module>` plus a function, record, record field, or example of that name; or
     `<module>.<Record>` plus a field of that record. Methods spelled with `:` resolve
     the same way as `.`.
   - Excuses, the whole allowlist: `HISTORY` files by prefix, copied from
     `doc_paths_test.tl` and extended with `docs/agent-usability.md` ("a dated study
     log; its header says so"); `docs/decisions/` by prefix ("a record names the tree
     of its day"); named `SPANS` for a symbol that is the reader's own
     (`cosmic.mymod.greet`). An excuse nothing needs fails, as in `doc_paths_test.tl`.
   - The failure message: `<file>:<line>: `<span>` names no symbol in the doc index
     (nearest: <up to 3 names by cosmic.fuzzy.distance under 4)` — the same fuzzy the
     `--docs` not-found path uses, so the fix is in the message.
3. Fix the two remaining live spans in the same PR: `AGENTS.md:129` resolves once
   step 1 lands; `docs/design/make/phasing.md:108` and `:175` are file paths written
   with dots (`cosmic._make.pin`, `cosmic.mk.lint.got`) — rewrite them as the paths
   they are, so `doc_paths_test.tl` checks them instead.
4. `docs/guides/lint.md` is unchanged (a `_build/` ratchet, not a `--check lint`
   rule); `docs/contributing.md`'s gate list gets the one line the paths gate has.

## Non-goals

Bare `fs.read`-style spans (ambiguous without the module). Doc-comment prose inside
`.tl` files (cross-module references there are the compiler's business: a wrong module
name in a comment is not a broken pointer a reader pastes). Spans in the work board's
specs. `@param`/`@return` tags against signatures — a different disagreement, its own
item.
