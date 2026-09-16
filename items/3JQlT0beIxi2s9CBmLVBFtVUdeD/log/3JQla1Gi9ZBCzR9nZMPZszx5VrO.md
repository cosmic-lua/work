Evidence, observed in a Claude Code remote session's harness clone of
cosmic-lua/work on 2026-09-16 after `refresh --execute`:

    git branch -vv      -> main 8aa4dc4c1 [origin/main] (#133, 2026-09-12)
    git rev-parse main origin/main -> both 8aa4dc4c1
    origin's real main  -> 43c08e19c (#205)
    branch.main.remote=origin, remote.origin.fetch=+refs/heads/*:refs/remotes/origin/*

`refresh --execute` fetches only the state and board/format refspecs
(`fetch_refspecs` in `_work/refs.tl`), so `origin/main` stayed four days
stale. With upstream configured and the two refs equal, `stale_target` returns
"nothing wrong" and `product_base` records 8aa4dc4c1. This is the shape
«xVrr_GZGP» was filed for; PR 194 added refusals for a missing or unresolvable
upstream, which this clone does not have. The behind-refusal itself predates
that item (PR 155, 2026-09-13).