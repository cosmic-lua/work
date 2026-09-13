No behavior changes anywhere — pure move plus import updates; every
existing store/publish/race test passes unmodified except for import
lines. No API renames. gitverbs.tl at 493 is NOT this item's problem;
the sweep result is stated above, not acted on.

---

(Original evidence prose, kept for the rationale the Change cites:)

`_work/store.tl` is exactly 500 lines — the lint cap — so the next line
added anywhere in that file fails `cosmic --make lint`, and every change
to it now carries a mandatory trim.

Measured after PR #1466 (item `3IVKVXoO`) merged:

    wc -l _work/store.tl   →   500

The cap is `≤ 500`, so nothing is red today. There is simply no headroom.
