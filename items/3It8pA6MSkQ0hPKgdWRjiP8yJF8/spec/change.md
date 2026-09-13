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
