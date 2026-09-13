Four files. Nothing else moves.

**1. `AGENTS.md` — the false claim, and the missing half of the narrowing
note.** Measured: `grep -rn 'forces callers to narrow' --include='*.md' . |
grep -v '^./o/'` prints exactly two lines, `AGENTS.md:152` and
`docs/stdlib.md:38`, and nothing else. `wc -l < AGENTS.md` prints **454**.

Line 152 today reads

```text
- **Fallible value**: `T | nil, string` — the checker forces callers to narrow.
```

Replace it with a line that says where the force actually is:

```text
- **Fallible value**: `T | nil, string` — callers must narrow, and the checker
  only makes them at an index (`cosmic --docs guide.checking`).
```

Then, in the `**Narrowing nil unions.**` paragraph, lines 178–180 today read
`... What / still does NOT narrow: record FIELDS (copy the field to a local and
guard the / local). The other tools:`. Append one sentence to that same
paragraph, between `local).` and `The other tools:`:

```text
And what the checker never DEMANDS: an unnarrowed `T | nil` passes into a
non-nil parameter, a declared non-nil local, arithmetic and concatenation —
only an index refuses it, so an unguarded union becomes a runtime nil
downstream (pinned in `cosmic/teal_narrowing_test.tl`).
```

**2. `docs/stdlib.md` — the same false claim.** `wc -l < docs/stdlib.md` prints
**57**. Lines 37–38 today read

```text
- **fallible value**: `value | nil, string` — the primary pattern; the
  checker forces callers to narrow before use
```

Replace with

```text
- **fallible value**: `value | nil, string` — the primary pattern; callers
  must narrow before use, which the checker makes them do at an index and
  nowhere else
```

**3. `docs/guides/checking.md` — one new subsection.** `wc -l <
docs/guides/checking.md` prints **337**; its subsection headings are
`grep -n '^#\{1,3\} ' docs/guides/checking.md`, and `### Narrowing and
Casting` starts at line 64 and runs to `### Record Types` at line 198. Add a
new `### Where Narrowing Is Required` immediately before `### Record Types`,
carrying:

- the boundary in prose — an index (`s:upper()`, `t.field`, `a[i]`) is the only
  position that refuses an unnarrowed `T | nil`; assignment to a declared
  non-nil type, a non-nil parameter, arithmetic and concatenation all admit it;
- one `teal` fence showing the admitting positions (it compiles, which is the
  point);
- the index refusal shown in a `text` fence, with the checker's message
  (`cannot index key 'upper' in variable 's' of type string | nil`);
- one sentence saying what this means for a reader: a `| nil` annotation is a
  contract with the reader that the checker only half enforces, so guard at the
  boundary rather than trusting the annotation to force it downstream.

This guide SHIPS in the binary (`cosmic --docs guide.checking`), which is why
the acceptance below reads it back out of a built binary and not off disk.

**4. `cosmic/teal_narrowing_test.tl` — pin the boundary.** `wc -l <
cosmic/teal_narrowing_test.tl` prints **212** (288 lines of headroom under the
500-line cap); this addition is ~45 lines. The file's stated job is "teal_test.tl's
canary pins what must narrow; this file pins what must not", and the admission
boundary is exactly that. Add two functions at the end, each called on the line
after its `end` per AGENTS.md, following the file's existing shape (write a
snippet to `fs.join(tmpdir, "<name>.tl")`, run `teal.check_file(path)`, assert
on `result.ok`):

- `test_nil_union_is_admitted_outside_an_index` — one snippet carrying all four
  admitting positions from the probe table above, asserting `result.ok` and
  concatenating `result.errors`' messages into the failure message, modelled on
  `test_early_exit_is_guard_narrows` (declared at line 81, called at line 121 in
  the file today).
- `test_nil_union_is_refused_at_an_index` — the negative twin, modelled on
  `test_error_terminated_guard_does_not_narrow` (declared at line 196): the same
  `gs(): string | nil` stub, indexed without a guard, asserting `not result.ok`.
  Without it the positive test would pass under a tl bump that made the checker
  strict and would pin nothing.

If either test ever fails, the checker's boundary moved and the three prose
sites above are the thing to update — that coupling is the whole point of the
pin.
