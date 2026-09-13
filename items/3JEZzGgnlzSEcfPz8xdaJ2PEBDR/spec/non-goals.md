- `multipart/form-data`: its own item, named here so a puller does not
  fold it in.
- Signed/encrypted session cookies (needs the `cosmic.crypto` decision,
  «Y45A_uF50»): out of scope; the guide shows a server-side session
  table keyed by a `cosmic.rand` token instead.
- CSRF tokens: an app-level pattern the guide shows; no server support
  in this slice.
