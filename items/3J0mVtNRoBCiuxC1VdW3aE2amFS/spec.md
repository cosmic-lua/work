## Evidence

See the parent outcome («AP77_4XCs») for the full evidence trail.
`_work/brieftext.tl`'s `BUILDER` template — the ONE shared prompt every
builder gets, regardless of target repo — hardcodes, inline, in prose:
`` `bin/cosmic --check types <file>` `` (line 59), `` `bin/cosmic --make
test _build/<name>_test.tl` `` (line 64), `` `bin/cosmic --make ci` for
cosmic; `make -j$(nproc) o//tool/lua/test` for cosmopolitan `` (lines
73-74), `` `bin/cosmic --make coverage` `` (line 76), `` `bin/cosmic
--make build` `` (line 78). `_work/brieftext_review.tl` does the same
for the review template — `bin/cosmic --make test <file>` (line 116),
and, landed this session (item `s2ac_B5wz`), `bin/cosmic --make fetch`
for a fresh review checkout (lines 134, 223). Every one of these is a
fact about `cosmic` specifically, asserted as if it were true of
whatever repo the item being built happens to target.

Depends on the sibling item («oJ31_ppvR», the repo-mechanics resolver)
landing first.

## Change

`_work/brief.tl`'s template-filling step gains the item's resolved repo
kind (via «oJ31_ppvR»'s resolver, resolved from the local checkout of
the item's `repo`) as fill data — the same four commands the resolver
already builds (bootstrap, gate, check-file, test-file), regardless of
whether they came from the `cosmic` convention or a `make` kind's
targets. `_work/brieftext.tl`'s `BUILDER` template and
`_work/brieftext_review.tl`'s `REVIEW`/`REVIEW_SCRIPT` templates replace
every hardcoded `bin/cosmic ...`/`make ...` command named in Evidence
with a filled placeholder sourced from the resolved commands
(`<TYPE_CHECK_CMD> <file>`, `<GATE_CMD>`, `<TEST_CMD> <file>`,
`<BOOTSTRAP_CMD>` — name them to match whatever the resolver actually
returns). When the resolver comes back absent for an item's repo, the
templates fall back to today's literal `cosmic`-specific text exactly as
written now — this is additive for `cosmic-lua/cosmic` and
`cosmic-lua/cosmopolitan` until cosmopolitan's own Makefile carries the
four targets, not a behavior change for either.

The `for cosmic; ... for cosmopolitan` two-repo enumeration at
`brieftext.tl:73-74` goes entirely once cosmopolitan's Makefile exposes
the four targets — one filled placeholder replaces both hardcoded
branches, and a third product repo needs no gitboard-side edit at all,
only its own `bin/cosmic` or its own four Makefile targets.

Tests: a fixture item whose repo resolves to a `cosmic` kind, asserting
the rendered brief names the cosmic commands, not the hardcoded fallback
text; a fixture item whose repo resolves to a `make` kind, asserting the
rendered brief names the make-target commands; a fixture item whose repo
resolves to nothing, asserting the fallback text renders exactly as
today (regression guard).

## Non-goals

Not resolving the file-length-cap instruction (`brieftext.tl:55`) —
that's the sibling item scoped separately, since it's arguably not a
"command" question at all (see that item). Not adding the real Makefile
targets to `cosmic-lua/cosmopolitan` — proving the fill-and-fallback
behavior against a fixture is this item's job.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
