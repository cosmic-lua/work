- **No test, example or benchmark file.** The sibling item
  (`3IOegofM`) owns the 38 test-side sites; a diff touching a
  `*_test.tl` beyond what a widened signature forces is scope creep.
  The two signature widenings force nothing: every caller listed in
  `Evidence` already handles the nil slot.
- **Do not touch `_tool/coverage/report.tl`.** Its 2 sites need a
  combinator `cosmic.shape` does not have.
- **Do not touch `_eval/stage.tl:239`.** It is the dynamic-value
  boundary class, another item's work.
- **Do not change `cosmic/shape.tl`**, its tests or its example. The
  mechanism is landed and frozen; if a site cannot be expressed, leave
  the site and file a capture rather than widening the module.
- **Do not widen what any affected loader accepts.** `shape.into`
  ignores keys a Spec does not name, so a payload that grows a field
  still loads; a payload MISSING a field the code reads must still
  fail, with the loader's own path-prefixed message where it has one.
- **Do not change any of these modules' public return contracts**
  beyond the two nil widenings named in `Change`, which make an
  existing runtime nil visible in the type.
- **No new `as` cast and no new `-- cast:` line anywhere in the diff.**
