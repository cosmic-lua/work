## Evidence

The review brief tells the reviewer to record the verdict with a binary that
no longer exists where it points. `git grep -n "o/bin/gitboard verdict"
origin/main -- _work` (cosmic-lua/work, 2026-09-05) matches
`_work/brieftext_review.tl:74` and `:157`: the block reads

    cd /home/user/cosmic/o/board
    export SSL_USE_SYSTEM_CERTS=1
    o/bin/gitboard verdict <ITEM_ID> <accept|request-changes|reject> \
      --pr N --head SHA --session review-...

Since cosmic-lua/cosmic#1712 the board checkout at `o/board` is a plain
clone of cosmic-lua/work with no build in it; the tool is the pinned release
`bin/gitboard` runs from the product checkout, which exports
`GITBOARD_DIR=o/board` itself (cosmic's `bin/gitboard`, `GITBOARD_DIR`
line). A reviewer following the brief literally gets `o/bin/gitboard: not
found`; the orchestrator of the first review under the new bootstrap
(«98RT_EE0A», 2026-09-05) had to override the command by hand. The
`SSL_USE_SYSTEM_CERTS` line predates the trust root too: nothing in the
verdict path reaches GitHub through cosmic's TLS except the PR check, and the
brief should say so only if it is still needed (measure: run `verdict` from
a fresh session without it).

## Change

1. `_work/brieftext_review.tl`: both verdict blocks become

       cd <PRODUCT_ROOT>
       bin/gitboard verdict <ITEM_ID> <accept|request-changes|reject> \
         --pr N --head SHA --session review-...

   where `<PRODUCT_ROOT>` is filled by `brief` from the board's product
   (`_work/product.tl` names the repo; the checkout root is the directory
   holding `bin/gitboard`, which `brief` can take from the `GITBOARD_DIR`
   it was run under: its parent's parent). Keep the `SSL_USE_SYSTEM_CERTS`
   export only if the measurement in Evidence shows the verdict's PR-head
   check fails without it; record the result in the template's comment.
2. `_work/brieftext_builder.tl` (and any other `brieftext_*.tl`): grep for
   `o/bin/gitboard` and `o/board` and fix every stale path the same way —
   `grep -rn "o/bin/gitboard\|o/board" _work/brieftext_*.tl` is the sweep,
   paste its before/after count in the PR.
3. Tests: `_work/brief_test.tl` (or the existing brief test file) asserts
   the rendered review brief contains `bin/gitboard verdict` and does not
   contain `o/bin/gitboard`.

## Non-goals

Changing what the verdict verb does; changing the accept/request-changes/
reject wording; the builder brief's `Bootstrap it first` paragraph, which is
still right for a product checkout.
