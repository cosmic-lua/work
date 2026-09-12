# make: the fence's read grant for `run` and the generator mini-graph is inherited, not decided

Source: cosmic-lua/cosmic#837 (open, no board item)

## Goal

`_cli/grants.tl` derives an explicit, reasoned fence grant for every
verb whose step needs one — today it does that for `record` (a test)
and `exec`, each with its reasons written in the file. `--make run`'s
target spawn and the generator mini-graph's closure compile
(`_make/closure.tl`) need reads too, but neither goes through the
derivation at all right now, so what they get is either nothing or
whatever an enclosing fenced step happened to leave lying around.
Settle what each should have, and write it down in `_cli/grants.tl`
beside the reasons already there — the same place issue #837 asks for.

## Evidence

`_cli/grants.tl` derives grants only for verbs reached through
`cosmic -c '<line>'`, which is `_cli/driver.tl`'s whole job:

```
$ sed -n '1,3p' _cli/driver.tl
--- The build-driver entry point behind `-c`:
--- fence the step, then run it.
$ grep -n 'if verb == "record" then\|if verb == "exec" then' _cli/grants.tl
301:  if verb == "record" then
350:  if verb == "exec" then
```

There is no `if verb == "run"` (or any mini-graph-specific branch) in
that file — grep for either name in it returns nothing:

```
$ grep -n '"run"\|mini.graph\|generate' _cli/grants.tl
$
```

`--make run` (`_make/runverb.tl`) never calls into `_cli.driver` or
`cosmic -c`; it spawns the target directly:

```
$ grep -n "local res, rerr = child.run(child_argv" _make/runverb.tl
185:  local res, rerr = child.run(child_argv,
$ sed -n '184,187p' _make/runverb.tl
  local dup0, derr = unix.dup(0)
  if dup0 == nil then
    return stage.verdict("run", false, "dup stdin: " .. tostring(derr))
  end
```
(the actual spawn two lines below takes `{cwd = proj.root, stdout =
"inherit", stderr = "inherit", stdin = stdin0}` — no fence option, and
`cosmic.child.run` has none to give it: fencing is `_cli.driver`'s job,
and this call never reaches it.)

The generator mini-graph's closure compile is the same shape, one
layer lower — it calls the build vocabulary IN PROCESS, not through
`-c`:

```
$ grep -n 'local build = require\|build.dispatch(verb, args)' _make/closure.tl
4:local build = require("_cli.build")
159:      if build.dispatch(verb, args) ~= 0 then
$ sed -n '142,144p' _cli/build/init.tl
local function dispatch(verb: string, args: {string}): integer
  local run_verb = modes[verb]
  if not run_verb then
```
`dispatch` here is a plain function call inside the already-running
`--make` process (`_cli/build/init.tl:142-148`) — never a `cosmic -c`
subprocess, so `_cli/driver.tl`'s fence-then-run never runs for it
either.

Net effect, verified by absence and by reading both call sites: a
bare `cosmic --make run foo.tl` or a cold `--make build`'s first
generator pass gets **no derived fence at all** for that step. The
"inherited" framing in the issue is accurate for the one case where
these run *nested inside* an already-fenced `record` step (a test that
itself calls `--make run`, e.g. `_make/resolution_test.tl`'s
`test_resolution_does_not_inherit`) — there, Landlock's own
non-revocable semantics mean the child spawn and the in-process
compile both operate under whatever policy the outer `record` step
already applied, by accident of nesting rather than by any grant
`_cli/grants.tl` names for them. Run standalone, they get nothing.

`docs/design/make/resolution.md`'s "Open" section (last touched by an
unrelated coverage-wording commit `2b2002d`, 2026-09-07, after the
mini-graph and `run` both landed) still lists this exact question as
unsettled:

```
$ grep -n "draws the line for .run. and the generator" docs/design/make/resolution.md
- **Where the fence draws the line for `run` and the generator
```

## Change

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

## Non-goals

- Not fixing the nested-fence depth ceiling (cosmic-lua/cosmic#839,
  separate item) — this item is about *what* grant `run` and the
  mini-graph get, not the kernel/Landlock stacking limit uncovered
  while testing them.
- Not changing `record`'s existing grant shape.
- Does not resolve `engine.md`'s open "a channel for *I read this
  file* that is not `require`" question — the mini-graph's grant here
  can be derived from the closure the graph already computes, without
  that channel.

## Access

- cosmic-lua/cosmic — read+write (the only repo this spec touches).

## Proposed board placement

Parent candidate: `«lei5_yM5b» G4 — zero-config project gates`
(container, `todo`, rank "outcome 11 of 34") — this repo's `--make`
correctness/gate-design umbrella; its existing children include other
`_make`/fence-shaped gaps (`PxMM_mVMH` concurrent-build corruption,
`jVjr_G7kp` a build lock, `kxFt_bsTF` a cold-build boot-surface gap).
No item specifically about fence-grant derivation for `run`/mini-graph
was found (`gitboard find "grants"`, `"mini-graph"`, `"fence"` — none
match); G2 (`hc6R_jxJB`, sandbox/Landlock ABI coverage) was considered
and rejected as parent since its children are C-layer Landlock ABI
work, not this repo's `_cli/grants.tl` policy-derivation question.
