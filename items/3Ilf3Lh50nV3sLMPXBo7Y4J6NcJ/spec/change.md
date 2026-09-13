`libc/intrin/gcov.c` `__gcov_exit`: if `info->filename` exists and
its header (magic, version, stamp) matches, read its counter records
and add them to the live counters before writing (GCC 14.1's
`libgcov-driver.c` merge; `__gcov_merge_add` semantics), with a
length/checksum mismatch treated as a fresh file. The cov test rule
keeps deleting `.gcda` before the run so a build starts clean. Record
the per-file `Lines executed` table after the change in the PR; a
follow-on item may then ratchet it.
