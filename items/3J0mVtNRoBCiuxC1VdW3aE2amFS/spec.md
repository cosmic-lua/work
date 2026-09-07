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

Depends on the sibling item («oJ31_ppvR», the manifest + reader) landing
first.

## Change

`_work/brief.tl`'s template-filling step gains the item's own manifest
(read via «oJ31_ppvR»'s reader, resolved from the item's `repo`) as
fill data. `_work/brieftext.tl`'s `BUILDER` template and
`_work/brieftext_review.tl`'s `REVIEW`/`REVIEW_SCRIPT` templates replace
every hardcoded `bin/cosmic ...` command named in Evidence with a filled
placeholder sourced from the manifest (`<TYPE_CHECK_CMD>
<file>`, `<GATE_CMD>`, `<TEST_CMD> <file>`, `<BOOTSTRAP_CMD>`, and so
on — name them to match whatever fields «oJ31_ppvR» actually landed).
When an item's repo has no manifest, the templates fall back to today's
literal `cosmic`-specific text exactly as written now — this is
additive for `cosmic-lua/cosmic` and `cosmic-lua/cosmopolitan` until
each adopts a manifest, not a behavior change for either.

The `for cosmic; ... for cosmopolitan` two-repo enumeration at
`brieftext.tl:73-74` goes entirely once a manifest exists for both —
one filled placeholder replaces both hardcoded branches, and a third
product repo needs no gitboard-side edit at all, only its own manifest.

Tests: a fixture item whose repo carries a manifest, asserting the
rendered brief names the manifest's commands, not the hardcoded
fallback text; a fixture item with no manifest, asserting the fallback
text renders exactly as today (regression guard).

## Non-goals

Not resolving the file-length-cap instruction (`brieftext.tl:55`) —
that's the sibling item scoped separately, since it's arguably not a
"command" question at all (see that item). Not writing manifests for
real product repos — proving the fill-and-fallback behavior against a
fixture is this item's job.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
