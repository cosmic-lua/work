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
