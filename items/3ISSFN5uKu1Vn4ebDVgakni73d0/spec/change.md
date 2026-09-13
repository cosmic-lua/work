Delete the three `-- cast: or fallback does not narrow` casts in
`_cli/build/init_test.tl` and their comment lines, then regenerate the
casts floor.

Measured 2026-08-26 against `main` `ec794d44`:

- `grep -rn "or fallback does not narrow" --include=*.tl . | grep -v "^./o/"`
  returns exactly 3 lines, all in `_cli/build/init_test.tl`, at lines
  72, 144 and 169 (the comment; the cast is on the line below each).
- `wc -l < _cli/build/init_test.tl` is 260 — 240 lines of headroom
  under the 500-line cap; this change only removes lines.
- `grep -n '_cli/build/init_test.tl' _build/casts_baseline.tl` is
  `3:  ["_cli/build/init_test.tl"] = 3,` — one row, count 3.

The three sites are two spellings of the same shape:

```teal
  -- cast: or fallback does not narrow
  local lua = (fs.read(out) or "") as string      -- lines 72-73
  -- cast: or fallback does not narrow
  local written = (fs.read(out) or "") as string  -- lines 144-145, 169-170
```

Replace each two-line pair with the single cast-free line, keeping the
same local name and indentation:

```teal
  local lua = fs.read(out) or ""
  local written = fs.read(out) or ""
```

Then rewrite the committed floor with the command the ratchet's failure
message prints — `bin/cosmic --make run _build/casts.tl --baseline` —
and commit the result. `_build/casts.tl`'s `main` writes only files that
still hold casts, so the `_cli/build/init_test.tl` row is REMOVED from
`_build/casts_baseline.tl` rather than set to 0; that is the expected
diff, and no other row should move. Verified 2026-08-26: the regen
produced exactly that one-line baseline deletion.
