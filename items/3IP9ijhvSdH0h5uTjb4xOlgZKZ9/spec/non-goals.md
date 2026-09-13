No change to the mode vocabulary (legacy/runner/mixed/empty), to the
immediacy rule (the call sits on the next non-blank line after `end`),
or to the referenced-elsewhere disqualifier. No edits to
`_tool/seam.tl` or `_cli/lint.tl` — both consume `discover.discover`
and inherit the fix. No test file migrates to runner mode here (that is
3IU6AZEx and its siblings). The formatter's separate keyword walk
(`cosmic/format/types.tl`) was fixed by 3ISWuGko and is not touched.
