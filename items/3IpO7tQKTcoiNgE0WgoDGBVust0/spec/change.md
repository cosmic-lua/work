Move `closure_argv` and the include-path helpers it owns (the block at
:108-217, including the comment block that documents the seed
fallback) into a new `_make/closure.tl` exposing `argv(...)` with the
same signature; `generate.tl` requires it and keeps `run_generator`,
the stamp digest and `sources()`. No behaviour change: the existing
`_make/generate_test.tl` cases that spy on `closure_argv`'s returned
flags (`test_closure_compile_includes_the_seed_dir_when_present` and
its neighbours) move to `_make/closure_test.tl` unchanged except for
the module name. Target: `generate.tl` under 400 lines, `closure.tl`
under 150.
