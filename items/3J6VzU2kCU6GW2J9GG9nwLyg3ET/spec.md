## Evidence

Measured at cosmic-lua/work `1dbd6fb7959576e5ab40f13b4d5d40bb4b5a58ed` while independently reviewing «CVYc_iYdJ»:

```sh
sed -n '255,300p' _work/brieftext_review.tl
sed -n '330,360p' _work/doctrine.tl
sed -n '330,375p' _work/brief_test.tl
```

`RESEARCH_REVIEW` tells the reviewer to read the board with `show`/Git grep and emits a verdict without `--head`. Current orchestration doctrine says agents never run board verbs, and current review doctrine says verdict evidence is the applying product commit. Existing tests deliberately pin the older research-review behavior, so this is a real policy inconsistency rather than an untested typo.

## Change

Refine the research-review authority and evidence model before implementation. Decide whether research review is still a supported distinct workflow; if it is, specify which caller-provided inputs replace agent board reads and which exact commit a durable verdict records. Align `RESEARCH_REVIEW`, doctrine, and its focused tests with that single decision. Preserve caller-owned authenticated transport and do not restore headless/PR/result verdict APIs merely for compatibility.

## Non-goals

No hard-coded board checkout path, provider reads by subagents, CI cache restoration, or changes to ordinary commit-review behavior without separate evidence.
