- **Do not edit `cosmic/time.tl`.** That is 3IPXQcgW, which this item
  unblocks; a doctrine change that lands inside the diff it licenses
  proves nothing.
- **Do not reopen D22 or D23's substance.** `check`'s exemption and the
  CSPRNG's stand; this is about whether the list is closed.
- **Do not widen this to "when may library code throw" in general.**
  The question is one shape, evidenced by one site.
- **Do not bless the tree's two existing undocumented library throws.**
  `cosmic/embed/init.tl:186` (`assert(loadfile("/zip/main.user.lua"))`)
  and `cosmic/quicksand/proxy/serve.tl:374`
  (`if not listen_fd then assert(listen()) end`) are REACHABLE failures,
  not unreachable-nil asserts, so the new rule must not admit them and
  the amendment must not mention them as though it did. They are filed
  separately as board item 3IQfhI33.
  (`git ls-files 'cosmic/*.tl' 'cosmic/**/*.tl' | grep -v '_test\.tl$\|_example\.tl$\|_benchmark\.tl$' | xargs grep -n 'assert('`
  reports 24 hits, 22 of them inside `---` doc comments; those two are
  the only executable ones, measured 2026-08-26.)
- **Do not add a lint for the `-- assert:` comment.** The convention is
  doctrine here; enforcing it is separate work, noted on board item
  3IQfhI33 and out of this diff.
- **Do not hand-edit `docs/decisions/README.md`'s table rows.**
  `_docs/derive.tl` owns them.
