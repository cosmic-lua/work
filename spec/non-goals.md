Not adding the real `bootstrap`/`gate`/`check-file`/`test-file` targets
to `cosmic-lua/cosmopolitan`'s own Makefile in this item — it lands the
caller and proves it against a fixture; wiring cosmopolitan's actual
Makefile is each repo's own follow-on once this and the sibling
brief-template item are both in place. Not changing what `bootstrap()`'s
verdict line looks like for the unrecognized-tree path.
