Lands in: whilp/cosmopolitan (set the item's repo when it is worked;
no verb sets it at capture time).

Research pass: 2026-08-23, per skills/optimize ("running a research
pass"): four round-1 agents (baseline read, cosmic sweep, C-layer/
startup sweep, literal-vs-json probe) plus a round-2 adversarial
verification. Tree at main 0fb444d6-equivalent. All numbers are
SCOUTING numbers, independently re-measured by the verifier where
stated; accept/reject stays with the _perf harness. C-layer A/Bs
depend on board item 3IHHJcVr (o//depend broken: header edits never
rebuild) landing first, or on clean rebuilds.

## Problem
embed_extract_tree 59.9ms cw1.01 (baseline; verifier reproduced the
scenario shape — 1228 files packed on the cosmic binary — at 31-35ms
on tmpfs, ~50ms disk-backed, so the baseline is consistent with a
disk temp dir). Extraction is: C reader with only read (lzip.c:672)
and save (703, open/write/close per file) verbs; the LOOP lives in
Lua (cosmic/zip.tl extract_entries, line 271) with a per-file
fs.set_mode chmod (332) and per-file path/guard work. Cosmic
self-extracts its build engine through this path.

## Rejected mechanism (recorded so nobody re-tests it)
"Per-member inflateInit2/inflateEnd churn ~40KB and ~3ms": REFUTED.
lzip.c decompresses one-shot with the full output buffer under
Z_FINISH, and vendored zlib skips window allocation entirely in that
mode (third_party/zlib/inflate.c:1323-1325) — per-member churn is one
~10KB inflate_state ZALLOC. Measured full init+inflate+end round trip
0.27µs — 1240 members ≈ 0.3ms, ~1% of the scenario. inflateReset2
stream reuse is valid (zip deflate is always raw -MAX_WBITS) but not
valuable.

## Change (re-scoped hypothesis)
A C-side bulk extract (reader:extract_all(destdir) or an iterating
save that takes the dest dirfd): walk the index once in C, reuse one
scratch buffer, openat against a dest dirfd, create each directory
once, set modes inline — removing per-file Lua dispatch, per-file
chmod calls, and path-string work. Verifier'\''s measured headroom:
save-all minus read-all is 4-5ms per 628 files/7.3MB on tmpfs
(~7µs/file open+write+close, more on disk); estimated 15-30% of the
measured 33ms scenario, larger on disk.

## Constraints
reader:read/save shapes frozen; a new method is its own deliberate
definitions.lua + type-regen change. THE HARD ONE: the zip-slip guard
is fs.is_unsafe_entry_name, deliberately the SINGLE definition shared
by zip/tar/embed (cosmic/zip.tl:267-269) — a C-side extract_all must
not create a second guard implementation (lzip.c'\''s IsUnsafePath at
776 guards the writer, not extraction). Either the C walk returns
names for Lua to vet before extraction (two-phase), or the invariant
is renegotiated at plan — a spec decision, not an implementation one.
Extend tool/lua/test_zip_security.lua either way. Also count the
cosmic-side rider: embed.write'\''s blind per-file appender:remove
(embed/init.tl:389, ~1ms of 24.5ms embed_run_tree) can ride along;
the appender'\''s 19ms close()-time archive rewrite is a separate,
unprobed C question.

## Risk
Medium — new C surface + security-sensitive path. Ambition
medium-high, contingent on the guard-invariant decision.

## Fresh scouting and design disposition — 2026-09-11

No bulk extractor was implemented or selected for immediate decomposition.
Source cosmic b0ab4e8fe2bb798296e68e96ae640f82c8c03c5f and cosmopolitan
 e748d6a1e40e6419a48f16a9626c287014bdb6b5 still have the Lua extraction loop
and shared guard. cosmic/embed/extract.tl now delegates to cosmic.zip.extract,
so any future fast path belongs there, not in a separate embed extractor.

On macOS arm64, a 120-directory / 600-small-file archive made with cosmic.zip
was read by the pinned runtime 2026-09-10-851d5ec, cosmos
2026.09.06-e748d6a1e (SHA256
10f66af3cfe6b55e3f97c058ddff5e6b0ba3faf6eef8c2462cb7372895e4e1c2).
Seven samples, monotonic wall time, medians per operation:

- list + shared guard + fs.join/dirname + mode mask, no writes: 0.569 ms
  (50 operations/sample; range 0.568–0.572 ms).
- list + reader:read of all files with CRC checks: 0.498 ms
  (20 operations/sample; range 0.495–0.508 ms).
- zip.extract to a different fresh destination each sample: 31.516 ms
  (one operation/sample; range 31.436–34.944 ms).
- zip.extract overwriting a pre-extracted destination: 23.038 ms
  (3 operations/sample; range 22.692–28.119 ms).

These are small-file diagnostics on this filesystem, NOT the full
embed_extract_tree harness, and NOT a C A/B. They do not demonstrate
15–30% headroom from moving Lua dispatch into C; filesystem work dominates
this fixture. Chmod cannot simply disappear: current extraction applies
exact permission bits after umask-filtered creation and overwrites existing
files. Keep the older zlib rejection, but do not spend a new C surface on
the old optimistic estimate without a measured mechanism that survives
those semantics. This item remains open as a hypothesis; no speedup or
not-planned resolution is asserted.

A compatibility probe created a.txt='first' mode0600 and b.txt='last!'
mode0755, then patched both ZIP filename occurrences b.txt -> a.txt without
changing lengths. Observed reader:read('a.txt')='first'; extracted a.txt
also contains 'first', but final mode is0755. This follows list's archive
order, FindEntry's first-member lookup and the final per-entry chmod.
A C walk by central-directory offset must not silently switch to last
member bytes. Future tests must freeze this behavior or split a deliberate
compatibility change. Also retain complete name/size validation BEFORE
creating destdir, the sole fs.is_unsafe_entry_name predicate, current
symlink/overwrite behavior, and existing failure/partial-output semantics.
No new claim of symlink containment is made by the current lexical guard.

Performance refinement selected W2CS_hqfO instead: source-backed probing
there exposes repeated whole-project projection scans with a smaller
behavior-preserving implementation surface. This note records why ZIP
was not chosen; it does not close, reorder or replace this hypothesis.
