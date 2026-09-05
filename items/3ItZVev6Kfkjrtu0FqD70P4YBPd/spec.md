## Change

`--check lint`'s file-length rule judges files that have no line
grammar at all: a binary swept in by the project walk. Every file the
walk sees is held to the 500-line cap on purpose, prose included, and
the carve-outs that exist are about what a file's OWN grammar can
express. A file whose bytes contain NUL has no line grammar, so the
rule has nothing to say about it; today it fails the gate and points
at `.cosmicignore`.

Measured 2026-09-05 with the pinned release
(`bin/cosmic.pin` → 2026-09-04-5d5dc3a) on a five-file project with a
copy of the cosmic binary in its root:

```
$ ./cosmic --make lint
✗ cosmic  113ms
6 checks: 5 passed, 1 failed
$ ./cosmic --check lint cosmic
cosmic:501:1: file-length: cosmic has 36766 lines (limit: 500) — a binary file, not text; lint gates every file the project walk sees, so if this one should not be judged, list it in .cosmicignore
```

Cost observed: in a break-and-recover experiment that placed the
previous release's binary beside the project as `./cosmic`, 13 of 13
Sonnet agents hit this failure on their first `--make ci`, and every
one resolved it by deleting the binary rather than writing
`.cosmicignore`; one journal calls it "a pre-existing lint failure on
the binary's file length". Each spent one gate cycle on it.

Change `_cli/lint.tl` at the file-length site (line 317 today,
`style.check_file_length(path, n, style.DEFAULT_FILE_LINES)`): when
`content:find("\0", 1, true)` is non-nil, skip `check_file_length`
and return no diagnostics for the file, before the rule runs. The
site already computes that sniff (line 324, to word the message);
move it above the call. The appended "a binary file, not text"
message branch becomes dead and goes; the "not Teal/Lua source"
branch stays, since prose stays under the cap.

Add to `_cli/lint_test.tl`: a fixture file of 4 KiB from a fixed byte
pattern containing NUL (not `/dev/urandom` — the test must be
deterministic) and more than 500 newline bytes, checked with the lint
verb, expecting zero diagnostics; beside it, keep the existing
behaviour for a 600-line `README.md` (one file-length diagnostic
carrying "not Teal/Lua source"), so the prose cap is pinned in the
same test.

## Non-goals

No change to which files the walk sees, to `.cosmicignore`, or to the
prose cap. Text files of any extension remain judged.
