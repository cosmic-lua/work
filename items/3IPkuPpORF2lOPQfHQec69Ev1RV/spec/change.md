For each of the 22 non-test `return` sites, choose per site and say
which in the commit:

- **widen the declared return** to `T | nil, string` where the failure
  is real and callers should handle it — this changes a published
  signature, so it needs the caller sweep in the same diff; or
- **guard at the call that produces the union** and return a documented
  fallback where the failure is genuinely unreachable — with the reason
  in the doc comment, not a cast.

Never a cast, and never `as` at a return.

The 22 test-side sites belong to the `check.must` sweep slice, not
here.
