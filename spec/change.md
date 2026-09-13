Curate a minimal `tl.Env` into `_types/gentl.tl`, following the
existing `Result`/`CheckOptions`/`EnvOptions` pattern (a hand-written
record body in the `PRELUDE` string, plus a `RECORD_FIELDS` entry that
`generate()`'s `verify_record` checks against the pinned source):

- add `Env = true` to `NAMED`
- add `RECORD_FIELDS["Env"] = {"report_types", "loaded"}` — only the
  two fields the follow-up item's `_teal_engine.tl` sites read
- add to the `PRELUDE` string:
  ```
  record Env
    report_types: boolean
    loaded: {string: Result}
  end
  ```
  (`Result` is already `NAMED`, so `loaded`'s value type resolves with
  no further change)
- `_types/gentl_test.tl`: update its `erase()` unit test for
  `tl.new_env`'s return from expecting `"any"` to expecting `"Env"`
  (the test's job is to pin what `erase()` does for this exact
  function; keeping it accurate is not scope creep).

Adding `Env` to `NAMED` is sufficient by itself for `erase()` to stop
mapping it to `any`; `tl.new_env`'s already-curated `FUNCTIONS` entry
picks up the new type automatically.

**The two required consumer-side casts** (both forced into existence
by curating `Env` at all — see the audit above; the build does not
pass cold or warm without both):

1. `cosmic/_teal_engine.tl`'s `process_source`, at
   `pcall(tl.process_string, input, false, env, name)` (currently
   line 239): change the argument to `env as Env` with a trailing
   `-- cast: env's declared type stays any until
   3IortEJ5fOuRnJ7OpJMfuXzMkSX retypes build_env/process_source; this
   cast only satisfies tl.process_string's now-curated 4th parameter
   and is removed by that follow-up, not by this item`.
2. `cosmic/_teal_ast_test.tl`, at `tl.process_string(code, false, env,
   "probe.tl")` (currently line 51): change the argument to `env as
   Env` with a trailing `-- cast: env comes from teal_ast.new_env,
   still declared any pending 3IortEJ5fOuRnJ7OpJMfuXzMkSX; this cast
   only satisfies tl.process_string's now-curated 3rd parameter here
   and is removed by that follow-up, not by this item`.

Do NOT change `env`'s declared type, `build_env`'s declared return,
`process_source`'s declared return, `env_cache`'s declared type,
`teal_ast.new_env`'s declared return, or touch the two `{string: any}`
casts at `_teal_engine.tl` lines ~231-232 — all of those stay
`3IortEJ5fOuRnJ7OpJMfuXzMkSX`'s job unchanged.

This adds two new cast sites (one each in `cosmic/_teal_engine.tl` and
`cosmic/_teal_ast_test.tl`, both already in `_build/casts_baseline.tl`'s
ratchet). Measure each file's current row before this change and
update both to reflect the added cast; do the same for
`docs/design/cast-sites.tsv` (add two rows for these new sites, do not
touch the three existing `_teal_engine.tl` rows the follow-up item
owns) via `bin/cosmic --make run _build/casts.tl --baseline` and
`bin/cosmic --make run _build/cast_sites.tl --reconcile`, then commit
both. `_build/casts_test.tl`/`_build/cast_sites_test.tl` fail until
they match.

Verify with `bin/cosmic --make ci` passing, AND a genuinely cold
build succeeding — `rm -rf o && bin/cosmic --make fetch && bin/cosmic
--make build` — since this is exactly the scenario all three prior
build attempts found broken; confirming a cold build is this item's
own proof the fix is complete. If a cold build STILL fails at a
different site than the two named above, the exhaustive audit above
was wrong somewhere — STOP and report the new site with its exact
error text rather than patching it silently; do not attempt a fourth
guess.

No `3p/tl/tl_pin.tl` bump: everything cited above is read from the tl
this tree already has pinned (`3p/tl/tl_pin.tl`'s `version =
"0.24.8"`), fetched fresh for this refinement.
