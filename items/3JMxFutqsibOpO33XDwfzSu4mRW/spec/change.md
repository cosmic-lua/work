Both trust roots cache their verified pin inside the repository's build output
directory, so a fresh container re-downloads them. Measured in this checkout:

    ls -la o/bootstrap/
    -rwxr-xr-x  9403848  cosmic
    -rwxr-xr-x 10234219  gitboard

19.6 MB, and `o/` is build output that `--make clean` removes and Git ignores
(`git check-ignore -v o/bootstrap/gitboard` -> `.gitignore:2:o/`). Two cold
downloads on every new container, for two binaries whose content is fixed by a
sha256 in a committed pin.

`bin/gitboard` sets `BOOTSTRAP="${ROOT}/o/bootstrap/gitboard"`
(`grep -n 'BOOTSTRAP="${ROOT}/o/bootstrap/gitboard"' bin/gitboard`) and decides
whether to re-download by comparing a sibling marker file against the pin:

    if [ -x "${BOOTSTRAP}" ] &&
        [ "$(cat "${BOOTSTRAP}.pin" 2>/dev/null)" = "${sha256}" ]; then

`grep -n 'cat "${BOOTSTRAP}.pin" 2>/dev/null' bin/gitboard`

Move the cache out of `o/` and key it by the digest instead of by a marker:

1. In `bin/gitboard`, set the cache directory to
   `${XDG_CACHE_HOME:-${HOME}/.cache}/cosmic-lua` and the binary path to
   `${CACHE_DIR}/gitboard-${sha256}`, computed after the pin is read (the
   `sha256="$(sed -n 's/^sha256 *= *//p' "${PIN}")"` line,
   `grep -n "sha256=\"\$(sed -n" bin/gitboard`). The path now asserts the
   content, so delete the `${BOOTSTRAP}.pin` write
   (`grep -n "printf '%s\\\\n' \"\${sha256}\" > \"\${BOOTSTRAP}.pin\"" bin/gitboard`)
   and reduce the skip test to `[ -x "${BOOTSTRAP}" ]`.
2. Fall back to the old `${ROOT}/o/bootstrap` path when the cache directory
   cannot be created (a read-only or absent HOME): try `mkdir -p` on it and, on
   failure, reassign both variables to the current in-repo path before
   `ensure_bootstrap` runs. A host without a writable HOME keeps today's
   behaviour rather than failing.
3. Apply the same three changes to `bin/cosmic` in cosmic-lua/cosmic, whose
   bootstrap block is the same shape against `bin/cosmic.pin`.

A pin bump now lands on a new path and downloads once; the superseded file
stays until something prunes it, which nothing here does.

The wall: the verification order is the trust chain and does not move. The
download still goes to a `$$`-suffixed temp path, `verify_sha256` still runs
before `chmod +x`, assimilation still runs after verification, and the `mv -f`
into the cache still happens only after both — so a file is never executed
before its digest is checked. Keying the path by sha256 strengthens this
relative to today: the skip test no longer trusts a marker file that anything
able to write the cache directory could forge alongside a swapped binary.

Regression: `_cli/gitboard_root_test.tl` in cosmic-lua/cosmic already copies and
exercises `bin/gitboard` (`--- reads: bin/gitboard`). Add a case that points
HOME at a temp directory, runs the script twice, and asserts the second run
prints no `Downloading pinned gitboard...` line and that
`${HOME}/.cache/cosmic-lua/gitboard-<sha>` exists.
