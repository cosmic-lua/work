## Evidence

cosmic-lua/work#34 («TE1u_Un2i») fixed the review brief's two verdict
blocks, which told the reviewer to `cd <BOARD_DIR>` and run
`o/bin/gitboard verdict` — a binary that has not existed in a product
checkout's `o/board` since the pinned-release bootstrap. Its spec's sweep
(`grep -rn "o/bin/gitboard\|o/board" _work/brieftext_*.tl`) excluded
`_work/brieftext.tl` by glob, and that file carries the same stale shape
in the REFINE and DECOMPOSE templates (2026-09-05, head d39d8abf):

    _work/brieftext.tl:240  cd <BOARD_DIR>
    _work/brieftext.tl:242  o/bin/gitboard sync
    _work/brieftext.tl:261  `o/bin/gitboard help bar` ...
    _work/brieftext.tl:272  o/bin/gitboard spec <ITEM_ID> ...
    _work/brieftext.tl:303  cd <BOARD_DIR>
    _work/brieftext.tl:305  o/bin/gitboard sync
    _work/brieftext.tl:324  `o/bin/gitboard help bar` ...
    _work/brieftext.tl:329  o/bin/gitboard new "<child title>" ...
    _work/brieftext.tl:332  `o/bin/gitboard block <child-id> ...`

A refiner or decomposer following those briefs literally gets
`o/bin/gitboard: not found`, exactly the failure #34 removed for reviewers.

## Change

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

## Non-goals

Changing what refine, decompose, or any verb does; the builder brief;
the review brief (#34 owns it).
