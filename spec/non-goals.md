- No change to `unix.pledge` semantics; the SIGSYS is correct
  behaviour for a traced write under a pledge without `stdio`.
- No weakening of the assertion at line 69.
