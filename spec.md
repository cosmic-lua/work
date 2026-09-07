## Evidence

cosmic#1777 added the `$NAME:PATTERN` name-predicate suffix to `cosmic.ast.match` captures (`$F:^test_` matches a capture whose rendered name matches the Lua pattern), tested in `cosmic/ast/match_test.tl` and used by `_build`'s ratchets. `sys/help.md`'s `--find`/`--rewrite` grammar block documents `$NAME` and `$$$NAME` captures and, since the `$X as $T` item, the `as` form — but has no line for `:PATTERN`, so `cosmic --help` describes a grammar smaller than the one the binary accepts. Found by the jVEN builder while editing that block.

## Change

`sys/help.md`'s pattern-grammar block gains one entry for `$NAME:PATTERN` — a capture that also requires the captured node's rendered name (or, for a cast's `$T`, its rendered type) to match the Lua pattern — with one example (`$F:^test_`). `cosmic --help` is the block, so no other file changes; `_build/doc_symbols_test.tl` (or whichever test reads `sys/help.md`) keeps passing.

## Non-goals

No grammar change; no change to the `--docs guide` pages.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.

## Ready when

`o/bin/cosmic --help | grep -c ':PATTERN'` is at least 1 and `--make ci` is green.
