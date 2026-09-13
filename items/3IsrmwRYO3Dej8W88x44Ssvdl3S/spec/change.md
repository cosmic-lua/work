`_work/gitgraph.tl`: add an optional `base` parameter to `cmd_new`
(same position/shape as the existing `repo` parameter — nil/empty means
"unset, inherits today's fallback behavior") and thread it into the
constructed `item.Item` record (currently built at lines 82-87 with no
`base` field). `_work/gitboard.tl` (the CLI dispatcher, wherever it maps
`new`'s flags — grep `--repo` in the `new` command's flag parsing for the
existing pattern to mirror): add a `--base BRANCH` flag alongside the
existing `--repo OWNER/NAME`, so `gitboard new TITLE --parent ID --repo
OWNER/NAME --base BRANCH --spec-file FILE` files a correctly-based item in
one call instead of two.

`_work/gitgraph_test.tl` (or wherever «T6Gj_9ge9`'s split lands it —
check `_work/gitgraph_test.tl`'s current line count first with `wc -l`;
it was exactly 500/500 as of this writing and «T6Gj_9ge9» is already
in flight splitting it, so a fresh `wc -l` may show headroom in a
successor file instead): a new item filed with `--base` set carries that
exact base with no follow-up `set` call; a new item filed without `--base`
keeps today's exact fallback behavior unchanged (this Change adds an
option, it does not change the default).
