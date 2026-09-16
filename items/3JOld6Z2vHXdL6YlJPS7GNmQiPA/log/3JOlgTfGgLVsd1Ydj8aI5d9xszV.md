Found 2026-09-16 by a reviewer working board item «AAt2_Citw», which has
nothing to do with `--find`. It reached for `cosmic --find` to cross-check a
grep, got the crash, spent 2 tool calls and about a minute on it, and fell
back to plain `grep`. Its own account attributed the failure to the `work`
repo's bootstrap runtime being "not a full cosmic distribution".

That attribution was wrong, which is why this is worth recording: the
orchestrator reproduced it in cosmic-lua/cosmic itself, on the same pin
(2026-09-15-2d8f07c), so it is a cosmic defect and not a work-repo quirk.

Reproduced directly:

    bin/cosmic --find ''      -> /zip/_cli/find.lua:99: attempt to concatenate
                                 a nil value (local 'compile_err')
    bin/cosmic --find ' '     -> same
    bin/cosmic --find '--'    -> same

Contrast, all clean refusals on the same build:

    bin/cosmic --find 'authority('  -> find: refused: <pattern>:1:11: syntax
                                       error, expected ')'
    bin/cosmic --find 'a['          -> find: refused: <pattern>:1:3: expected
                                       an expression
    bin/cosmic --find '\["_'        -> find: refused: <pattern>:1:1: invalid
                                       token '\'
    bin/cosmic --find 'authority'   -> find: 0 hit(s) in 713 file(s)

So every pattern that fails to PARSE refuses correctly; only a pattern that
parses to nothing crashes.

The mechanism, read off the source: `compile_pattern` in `cosmic/ast/match.tl`
calls `node_mod.parse(desugared, "<pattern>")`, which succeeds on an empty
chunk. `parsed` being truthy takes the success branch and returns
`attach_predicates(parsed.node[1], last_predicates)` with `parsed.node[1]`
nil — so the function returns `nil, nil`. `_cli/find.tl:99` concatenates that
nil message and throws.