In `_cli/grants.tl`, add one derivation branch per case, next to the
existing `if verb == "record"` (line 301) and `if verb == "exec"`
(line 350) branches, each stating its own reason the way `record`'s
comment does (lines ~301-324):

1. **`run`**: give it the same boundary as `record` — `ro = "."`
   (read the whole project), `exec = "."`, plus the `RUNTIME_RO`
   (`grants.tl:53`) / `RUNTIME_RW` (`grants.tl:79`) lists — because
   its target is arbitrary project code with the same "argv says
   *run this compiled file* and nothing about what the file does"
   shape the `record` comment (lines 331-333) already gives as the
   reason for a directory-wide grant rather than a derived one. This
   requires wiring `_make/runverb.tl`'s spawn (line 185's `child.run`
   call) to go through `_cli.driver`'s fence-then-run instead of a
   bare `child.run`, so the grant this adds is actually consulted.
2. **The generator mini-graph**: give `_make/closure.tl`'s closure
   compile (the `build.dispatch(verb, args)` call at line 159) the
   generator's own computed closure as its read set — `deps.built_paths`
   (already computed two lines above, `closure.tl:~150` `built`) plus
   the generator's source subtree — rather than the whole project,
   since (per resolution.md) "it compiles a closure the model computed,
   so its reads *are* derivable." This requires the same routing change
   as (1): the in-process `build.dispatch` call has to become a
   fenced `cosmic -c 'compile ...'` subprocess (or `_cli.driver` needs
   an in-process fencing entry point) before a grant here means
   anything.

Both wiring changes are one mechanism (route these two spawns through
the same fence-then-run path `-c` recipe lines already use) applied at
two call sites; do it once as a shared helper in `_cli/driver.tl` (or
wherever fencing an in-process step for a non-`-c` caller is later
decided to live), not as two separate re-implementations.
