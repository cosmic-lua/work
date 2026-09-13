Move only. No signature change, no doc-comment rewrite, no field added or removed,
no new record, no function relocated, and no behaviour change of any kind — a
reviewer must be able to read this diff as a pure relocation.

Do not add the comment POST here; that is #1204's Change and a countermeasure that
lands inside the PR it enables proves nothing.

Do not touch `_work/api.tl`, `list_issue_comments`, or `_work/verbs.tl`. The
`_work/verbs.tl` split is the sibling half of this wrong turn and has its own card.

Do not relax or exempt anything in `_tool/lint.tl`'s `file-length` check. The cap
is doing its job here; the file is what is wrong.
