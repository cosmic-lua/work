Re-deciding whether `cosmic-lua/work`'s `main` should queue at all (this
item only closes the gap between "a ruleset already requires it" and "the
workflow can actually run under it" — D38 already decided main-repo PRs
land via the queue's auto-merge path, generically, and this repo's `main`
is exactly that shape); the board branch's own direct-push landing (D38
explicitly excludes it, unaffected here); bypassing the ruleset from
tooling (never attempted).
