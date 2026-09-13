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
