Route each site through `cosmic.shape` instead of a cast, deleting the
`as` at each of the seven lines above:

- **`_build/casts.tl:90`** — `out[file] = n as integer`: `n` comes from
  decoding `_build/casts_baseline.tl` (a literal chunk). Declare a
  `shape.record({[file] = shape.integer, ...})`-shaped spec for the
  baseline map (or, since the baseline is a flat `{string: integer}`,
  `shape.map(shape.string, shape.integer)` if a bare map combinator
  covers it — use `shape.integer_map` if the key is the string filename
  and `map` is meant for non-string keys; read `cosmic/shape.tl`'s
  combinator doc comments to pick the right one) and call
  `shape.into` on the decoded table once, before iterating.
- **`_tool/coverage/baseline.tl:132,138`** — the same decoded-baseline
  read: build the `Entry` (`{covered: integer, total: integer}`) as a
  `shape.record`, call `shape.into` once per row instead of casting `v`
  to `{string: any}` and then casting the two fields off it.
- **`_tool/coverage/baseline_test.tl:486`** — `new_rows[path]` is a
  decoded row read back for a test assertion; give it the same `Entry`
  spec and drop the cast.
- **`cmd/cosmic/embed_gen.tl:294,334`** — `declared` and `pin` are
  decoded config values; declare specs for the `.cosmic` and `.version`
  fields actually read and call `shape.into` before the field access.
- **`cosmic/literal_example.tl:20`** — `raw` is what
  `cosmic.literal`'s reader returns; declare its shape and validate.

Each replacement is `value, err = shape.into(raw, SPEC)` with the
existing error-handling pattern at that call site (most already sit
behind a fallible return or a test's `check.must`), never a bare
`check.must` swallowing a shape mismatch a caller could act on.

After all seven casts are gone, regenerate the committed baseline and
reconcile the site inventory:

    bin/cosmic --make run _build/casts.tl --baseline    # rewrites _build/casts_baseline.tl
    bin/cosmic --make run _build/cast_sites.tl --reconcile   # rewrites docs/design/cast-sites.tsv

then confirm the class is empty:

    git show HEAD:docs/design/cast-sites.tsv | awk -F'\t' '$3=="decoded data shaping"'   # (after committing) — empty

and delete the now-empty `### decoded data shaping` heading (and its
body, through the next `###`) from `docs/design/casts.md`, following
the precedent `git show cf416d85 -- docs/design/casts.md | grep '^-###'`
(that commit deleted `### proved-value narrowing` the same way, in the
same PR that emptied its class).

Gate with `bin/cosmic --make ci` — `_build/cast_sites_test.tl` checks
the reconciled tsv against a fresh walk and against every remaining
`### ` heading, so a stray site or an un-deleted heading fails there.
