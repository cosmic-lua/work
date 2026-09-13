- **Do not try to verify the grant itself.** The board has no way to
  know what a future session's access will be, and guessing would make
  the check both wrong and annoying. The gate checks that the
  requirement is DECLARED, not that it is satisfied.
- **Do not widen it into a general external-dependency checker.** The
  subject is repository read access, which is granted per repository and
  is what bounced `3IKuRFN5`.
