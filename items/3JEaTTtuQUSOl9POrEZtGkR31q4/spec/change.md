Remove `stub_token`/`restore_token` and their call sites from
`_work/ghwrite_test.tl`, along with the now-unused `cosmic.env` import if
nothing else in the file uses it. The cases themselves keep their existing
fake-transport setup and assertions unchanged — this removes scaffolding,
not coverage.

Confirm the file still passes on its own (`bin/cosmic --make test
_work/ghwrite_test.tl`) before and after, and that the removal is the only
behavioural difference: same case count, same assertions.
