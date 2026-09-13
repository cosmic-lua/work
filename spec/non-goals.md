- The default `show` output does not change — not its line order, not
  its history block, not the `gitboard-show:` verdict line. Whether
  history should move behind its own flag is a separate question and
  stays unanswered here.
- No new verb. This is `show`'s flags; there is no `spec-show`.
- `spec.READY_SECTIONS` and `spec.ready_gaps` keep their current
  behaviour and signatures — `section_of` is added beside them.
- `_work/gitview.tl` keeps `status`, `tree`, `next` and `find` exactly
  where they are; do not reorganize what stays.
- No change to how sidecars are stored or read (`store.read_spec`).
