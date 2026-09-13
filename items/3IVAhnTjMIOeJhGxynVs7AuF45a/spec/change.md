Migrate `_cli/citations_test.tl` to runner mode so its cases still run
inside the fixture cwd. The naive deletion is not enough here — the
chdir/restore pair has to stop bracketing the file and start bracketing
the RUN. Settle the shape during refinement; the two candidates:

- Drop the restore and the now-unused `ORIGINAL` (both deletions), and
  rewrite the header comment at lines 28-31 that promises a restore.
  A trailing blank line is left at EOF by the deletion and must go, or
  `fmt` fails with `have: <blank>  want: <eof>` on line 156.
- Move the chdir into a helper each case calls, leaving no
  process-wide cwd change at module scope.
