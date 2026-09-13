`bin/cosmic.pin`: set `url` to a `cosmic-lua` release asset that
contains `2724a719` (#1455), and `sha256` to that asset's digest.
Both lines together — the file is read by `bin/cosmic` with sed and
stays two plain lines. Nothing else in the repo changes.

Verify the chosen release actually carries the counter fix before
bumping, rather than trusting its date. `_types/tlast_test.tl` is the
shortest probe, because its `test_cache_thaws_on_fresh_tl` contains
`assert(thaw is function(any): (any, any), …)` — a `function` token in
type position, the shape the old depth walk lost:

```
printf 'local function test_a()\n  local f: function(any): (any, any)\n  assert(f == nil)\nend\n' > /tmp/probe_test.tl
<the-release-binary> --check types /tmp/probe_test.tl
```

must print `Type check passed`, where the current pin's binary emits
`unused function test_a`.
