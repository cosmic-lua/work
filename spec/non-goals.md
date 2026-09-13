- **Do not edit `third_party/sqlite3/sqlite3.c` or `third_party/sqlite3/shell.c`.**
  Both are vendored SQLite amalgamations. Deleting the dead includes would work,
  and would also put hand edits inside 200k+ vendored lines that every future
  re-vendor must re-apply. AGENTS.md: keep the fork mergeable with upstream —
  surgical diffs, no drive-by restructuring.
- **Do not modify `build/bootstrap/mkdeps` or its source.** Teaching the scanner
  to evaluate the preprocessor is a different, much larger change with its own
  correctness risk; the textual scan is deliberate.
- **Do not touch `Makefile`.** `:433`, `:666` and `:670` are cleared above.
- **Do not vendor the Tcl test harness or the qrf extension**, and do not define
  `SQLITE_TEST` or `SQLITE_QRF_H` anywhere.
- **No cosmic-side change.** No cosmos pin bump, no edit in whilp/cosmic. This
  slice lands in whilp/cosmopolitan only; consuming it is a later pin bump with
  its own item.
- **Do not widen this to a THIRD unresolved include.** The probe above says
  there is none. If `mkdeps` nonetheless names one after both stubs land, that
  is a finding for the board — file it with the failing output and stop, rather
  than absorbing it here.
