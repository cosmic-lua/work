Not adding CCR routes for `ready_for_review`/`convert_to_draft` — gitboard's
own verbs (`verdict`, `take`, `done`) never perform that transition today;
it stays an orchestrator-side concern. Not wiring this into `verdict accept`
itself — that is separate sibling work filed alongside this item under the
same decision (`f6jE_UJBu`). Not touching `merge_pull`/`post_review`/
`close_pull` — all three are plain REST already and unaffected by this
specific block.
