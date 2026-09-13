- **Do not change `cosmic/literal.tl`, `cosmic/_literal_lex.tl` or
  `cosmic/_literal_format.tl`.** If a property finds a real defect,
  that is a board capture (`gitboard new` with the seed, the
  iteration and the base64 input from the driver's own failure
  output), and the generator is bounded away from it with the item id
  in the comment. A fuzz slice that also fixes what it finds cannot
  say which of the two the green run proves.
- **Do not touch `_fuzz/driver.tl`, `_fuzz/source.tl` or
  `_fuzz/shrink.tl`.** The harness is what it is; if a property needs
  a draw the recorder does not have, that is its own item.
- **Do not add a literal entry to `.github/workflows/fuzz.yml`.** The
  workflow runs `--make test _fuzz`, which picks the new file up by
  position; nothing lists the properties.
- **Do not adopt PR #1346's `"compact"` layout as the default
  anywhere**, and do not make this slice depend on it landing.
