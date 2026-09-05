## Evidence

Neither cosmic nor cosmopolitan has a KSUID implementation today:
`cosmic --docs ksuid` finds nothing (2026-09-05), `ls cosmic/ | grep -i
ksuid` is empty, and `grep -rli ksuid` across cosmopolitan's `tool/net/*`
matches nothing. The only KSUID in the whole ecosystem is
`cosmic-lua/work`'s internal `_work/ksuid.tl` — 20 bytes (4-byte
big-endian seconds since the KSUID epoch, 2014-05-13, plus 16 random
bytes), base62-encoded to a fixed 27 characters with an ascending ASCII
alphabet, so lexicographic string order is creation order. It is a
complete, working, tested reference (`_work/ksuid_test.tl`, 5 cases:
shape, time round-trip, lexicographic-order-is-time-order, domain edges,
freshness) built ONLY on already-public `cosmic.rand`/`cosmic.time` —
no cosmo or C dependency at all — so it ports to `cosmic/ksuid.tl`
essentially unchanged, generalized out of its item-id-specific framing.

Not a duplicate of `cosmic.uuid.v7()`: both are time-sortable, but
UUIDv7's canonical hyphenated-hex string form isn't byte-sortable the
way KSUID's fixed-width base62 string is by construction (see
`_work/ksuid.tl`'s own header) — different tradeoff a caller who wants a
sortable string key would otherwise hand-roll.

## Change

1. `cosmic/ksuid.tl`: port `_work/ksuid.tl`'s `encode`/`is_id`/`new`/
   `time_of` essentially as-is — same 20-byte layout, same alphabet, same
   27-character width — so any existing KSUID (gitboard's own item ids
   included) decodes identically. Generalize the doc comments away from
   "for work items" framing.
2. `cosmic/ksuid_test.tl`: port the five existing test cases.
3. `cosmic/ksuid_example.tl` (`Example_*`): a short runnable example
   (`cosmic --examples ksuid`).
4. A one-line H1 module description so `cosmic --docs`/`cosmic --docs
   ksuid` serve it like every other module.

## Non-goals

A C/cosmo implementation for speed (its own item, blocked on this one);
exposing generation through `cosmic.sqlite` (its own item, blocked on
this one); changing the byte layout or algorithm `_work/ksuid.tl`
already proves — this is a port, not a redesign.
