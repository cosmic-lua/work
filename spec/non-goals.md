`spec.tl`'s GitHub-URL-slug extraction (`github_urls`/`reached_repos`/
`declared_repos`) — narrower and GitHub-specific, not clearly a stdlib
fit on its own; `spec.tl`'s `revision` (a pure git-blob-hash function) —
that belongs with the already-filed git plumbing module («teX8_bEiz»),
not here, since it's about git object hashing, not markdown; gitboard's
own spec-bar semantics (`READY_SECTIONS = {"Change"}`, the `## Access`
convention) — those stay in `_work/spec.tl`, built on the published
module once this migrates.
