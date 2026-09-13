`cosmic/codec_test.tl`, `test_latin1_roundtrip` (line 204 on origin/main): a
`check.must` rewrite kept the slot-1 narrowing and silently dropped the test's
slot-2 assertion. `check.must` (cosmic/check.tl:187) tests only `value == nil`;
it says nothing about slot 2, so `encode_latin1` returning `"…", "spurious"`
now passes a test that used to refuse it. Restore the slot-2 claim while
keeping the narrowing:

```teal
local function test_latin1_roundtrip()
  local original = "café résumé naïve"
  local encoded, err = codec.encode_latin1(original)
  assert(err == nil, "encode failed: " .. (err or ""))
  local decoded = codec.decode_latin1(check.must(encoded))
  assert(decoded == original, "roundtrip mismatch: got '" .. decoded .. "'")
end
```

`encode_latin1`'s contract is explicit about slot 2 (`return result, nil`,
cosmic/codec.tl:186) and D20 rule 11 / docs/decisions/d24-structured-failures.md
make "nothing in slot 2 on success" part of the fallible-return shape; the
file's own sibling tests still pin it (lines 26, 32, 38, 60), so this brings
line 204 back to the file's convention. No other file changes; the file is at
301 lines (`git show origin/main:cosmic/codec_test.tl | wc -l`).

The class, not the instance: the same sweep shape (a two-value binding plus
`assert(err == nil, …)` collapsed to `check.must(...)`) could recur in any
future nil-flow PR. The reviewer's check for it is one command over the PR:

```
git show --format='' -U0 <sha> | grep -n '^-' | grep -v '^[0-9]*:---' | grep -E 'err == nil'
```

Run it over the seven check.must sweep merges for this item's evidence (below);
it names exactly one site, this one. Record that command in the PR body so the
next sweep's reviewer runs it too.
