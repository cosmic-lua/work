Give the ready bar a way to see an out-of-grant source, so `check`
catches it instead of a claim.

Two halves, and the refinement decides how much of each:

- **the grammar** — a spec that names a repository other than the
  item's own `repo` field (or `whilp/cosmic`) states the read access it
  needs, in a named place `_work/spec.tl` can find. A URL or `owner/repo`
  reference is a cheap syntactic signal.
- **the gate** — `gitboard check` refuses `ready` for an item whose spec
  reaches a repository it has not declared, the same way it refuses one
  with no position in the priority order. The refusal names the
  repository, so the session either declares it or re-specifies the
  slice around a source it can reach.

Core tier by `enable.md`'s ordering, and it belongs there rather than in
prose: whether a spec names an out-of-grant repository is exactly the
kind of thing a machine can check, and a rule written into `decompose.md`
would reach only the sessions that read it.
