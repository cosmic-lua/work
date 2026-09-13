- no `board` branch on whilp/cosmopolitan; no move of its `perf`/`audit`
  issue queues — issues remain the inbound queue in both repos.
- no cross-repo `blocked_by` ids and no live foreign-issue state
  checking — the repo field scopes an item's PR, not the dependency
  graph; a cross-repo dependency stays a URL in the spec, now beside a
  tracked item instead of instead of one.
- no generalization past the two repos this project spans; no
  multi-token auth story — one GITHUB_TOKEN, and its reach is whatever
  GitHub grants it.
- importing #265 and #266 as items is the follow-up triage act once
  this lands, not part of this diff.
