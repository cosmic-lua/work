One commit: retire the two sites (delete the cast + its guard's
redundant half at fs/types.tl in favor of the pinned is-guard shape;
delete the typed-local copies at coverage/init.tl and update the
comment to name the closure-carry rule), plus whatever the
benchmark.tl re-check finds. Run the touched modules' tests
(`cosmic/fs`, `cosmic/coverage`) and full `--make ci` — the
cold-build lane (`_build/coldbuild_test.tl`) is the real gate here,
since these sources will now REQUIRE the patched checker.
