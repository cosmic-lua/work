Three investigations, each ending in a decision recorded in THIS
item's spec (append a `## Findings` section) plus zero or more filed
captures. No product-tree file changes; scratch probes only.

1. **or-fallback**: reproduce each of the three
   `_cli/build/init_test.tl` sites as a minimal probe file; run
   `o/bin/cosmic --check types` on the probe with the cast removed;
   classify the escaping shape (or conclude the reason is stale).
   Decision to record: patch-extension (file a capture with the
   anchored find/replace sketch and probe transcript) or truer reason
   (file a capture to re-justify the three casts; editing them is not
   this slice's).
2. **closure carry-through**: locate where tl resets narrowing facts
   at function entry (`grep` the patched `o/3p/tl/tl.lua` for the
   scope/facts machinery the `narrow-nil-union` helpers hook);
   prototype the smallest sound rule on the scratch copy — carry a
   narrowed local into a closure when no assignment to it exists
   anywhere after the guard — and probe both a sound case and the
   unsound one (reassignment after closure creation must still
   refuse). Decision to record: feasible with an anchor (file the
   capture with the sketch and both probe transcripts) or not cheaply
   provable (record why; the typed-local idiom stays, and the two
   in-tree comments remain its documentation).
3. **metatable<any>**: find the `is` refusal ("can never be") in the
   scratch copy; probe whether accepting a table-kinded is-target over
   a `metatable<T>` value type-checks the `cosmic/fs/types.tl:251`
   site without weakening any refusal a test pins. Decision to
   record: patch capture or truer-reason capture, as in (1).

Each finding in `## Findings` states its command and output verbatim,
dated — the same evidence bar a ready spec's measurements carry.
