A file-length cap is a property of the MERGE, not of either branch, and the
gate says so only as a note a caller can read past.

Measured: «BK2V_8tI0» and «9cnW_GG8u» each added one dispatch branch to
`_work/gitboard.tl`. Each was under the 500-line cap on its own branch and each
gated green. Merged, the file was 502 and `lint` failed. Neither commit
contains the defect; the merge does.

The local gate does warn:

    ci: HEAD is not a descendant of origin/main (origin/main a8383e991a5a);
    this gate judged the branch, CI judges the merge

but it is printed beside `ci: PASS`, so the verdict line says the change is
good while the note says the verdict is about a tree CI will never build. I
pushed on a branch-only green once and would have turned a PR red on a defect
present in neither commit.

Make the mismatch a gate outcome rather than a note: when HEAD is not a
descendant of the tracked base, `--make ci` ends `ci: FAIL (stale base)` with
the same sentence, and a flag (`--allow-stale-base`) keeps the current
behaviour for the deliberate case of gating a branch in isolation.

`grep -n "is not a descendant of" _make/*.tl` locates the note.
