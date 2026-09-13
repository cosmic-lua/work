- No file outside `cosmic/fs/**`; no library file (the `FileIter`
  declaration stays as is — it is a public API type and a separate
  decision).
- No checker change; no `docs/design/nil-flow.md` / `.tsv` edit; no
  committed strict checker.
- Do not change what a test asserts. Do not add a cast.
