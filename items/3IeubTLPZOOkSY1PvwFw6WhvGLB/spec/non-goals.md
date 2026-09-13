- **No context inference.** The generator does not scan surrounding markup to
  decide which escaper you meant. The type at the interpolation is the obligation,
  and it is written down.
- No change to `cosmic.html.escape` / `unescape` signatures.
