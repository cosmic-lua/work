`bin/cosmic.pin`: set `url` to a `cosmic-lua` release that contains
#1446's seam, and `sha256` to that artifact's digest. Both lines
together — the file is read by `bin/cosmic` with sed and stays two
plain lines. Nothing else in the repo changes.

Verify the chosen release actually carries the seam before bumping:
download it, and confirm a runner-mode file checks clean under it —

```
printf '\nlocal function test_probe()\n  assert(1 == 1)\nend\n' > /tmp/probe_test.tl
<the-release-binary> --check types /tmp/probe_test.tl
```

must print `Type check passed`, where the current pin's binary emits
`unused function test_probe`.
