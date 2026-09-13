1. `_work/brieftext.tl` REFINE and DECOMPOSE templates: every
   `cd <BOARD_DIR>` becomes `cd <PRODUCT_ROOT>` and every `o/bin/gitboard`
   becomes `bin/gitboard`, the form #34 established (the product checkout's
   `bin/gitboard` exports `GITBOARD_DIR` itself). Keep the
   `SSL_USE_SYSTEM_CERTS` export where #34 kept it, for the same measured
   reason.
2. `_work/brief.tl` fills `<PRODUCT_ROOT>` for these kinds the same way it
   does for review (derived from `GITBOARD_DIR`, surviving unfilled and
   named on the closing line when unset); no second derivation.
3. The sentence "gitboard is already built in the board checkout." that
   opens both templates' "Where to work" sections is corrected the way
   #34 corrected the review templates' twin: the tool is the product
   checkout's `bin/gitboard`, which runs the pinned release.
4. Tests: `_work/brief_test.tl` asserts the rendered refine and decompose
   briefs contain `bin/gitboard` and not `o/bin/gitboard`, and that
   `<PRODUCT_ROOT>` fills for both. The sweep
   `grep -rn "o/bin/gitboard\|<BOARD_DIR>" _work/brieftext*.tl` goes to 0;
   paste before/after counts in the PR.
