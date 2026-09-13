In `whilp/cosmopolitan`. The C change itself (steps 1–4) is unmoved
from the prior spec. Steps 5–6 add the stored-member concurrency
gate the recycle path needs; they are the only additions.

```c
#define ZIPOS_FREE_SLOTS 4
static _Atomic(struct ZiposHandle *) __zipos_free[ZIPOS_FREE_SLOTS];
```

1. **`libc/runtime/zipos.internal.h`** — delete `struct ZiposHandle
   *next;`. The design has nothing to link, and leaving it would
   re-create the vestige this work exists to resolve.
2. **`libc/runtime/zipos-open.c` — `__zipos_alloc` (`:56`), pop.**
   Only when `size == 0` (the stored-member bucket at `:127`, where
   `mapsize == sizeof(struct ZiposHandle)` exactly; this fork does
   not round it). Skip the freelist entirely when `__vforked`.
   Otherwise scan the slots and take the first that yields non-NULL
   from `atomic_exchange(&__zipos_free[i], NULL)` with
   `memory_order_acquire`; fall through to today's `mmap` when none
   does. **On the recycled path, store 0 into `h->refs`** before
   returning it. `size`, `zipos` and `mapsize` are set as they are
   today; `pos`, `cfile` and `mem` are re-set by `__zipos_load`.
3. **`libc/runtime/zipos-open.c` — `__zipos_drop` (`:49`), push.**
   Only when `h->mapsize == sizeof(struct ZiposHandle)`. After the
   existing refcount check and acquire fence, scan for an empty slot
   and claim it with
   `atomic_compare_exchange_strong(&__zipos_free[i], &expect_null, h)`
   using `memory_order_release`; on success return WITHOUT `munmap`.
   No mutex and no unbounded retry — at most `ZIPOS_FREE_SLOTS`
   single-word CASes — because this runs on the `@asyncsignalsafe`
   `__zipos_close` path (`zipos-close.c:30-33`, drop at `:43`), which
   is precisely where the removed upstream code's `pthread_mutex_t`
   was illegal. When no slot is free, `munmap` exactly as today: the
   cap is enforced here and the array never grows.
4. **`fork`/`vfork`** — nothing to add for `fork`: handles are
   `MAP_PRIVATE|MAP_ANONYMOUS` so a child gets its own COW copies, and
   every mutation is a single atomic word operation, so there is no
   half-done publish to inherit and no lock to inherit locked. Do NOT
   add a `pthread_atfork` handler. For `vfork`, the `__vforked` guard
   in step 2 is the whole treatment; push is already skipped by
   `zipos-close.c:40`.
5. **In `test/libc/runtime/BUILD.mk` — ship a stored zip member into
   `zipos_test`.** Add a small text asset (name it
   `test/libc/runtime/prog/stored_smoke.txt`, one line of ASCII is
   enough — the concurrency gate reads it, does not compare content)
   and give its `.zip.o` a private `ZIPOBJ_FLAGS += -0` so the
   packager stores it uncompressed. Model the rule on the existing
   `ftraceasm.txt.zip.o` private-flags block (`test/libc/runtime/
   BUILD.mk:99-102`) — the `-0` flag path is `tool/build/zipobj.c:140`
   (`case '0': nocompress_ = true;`). Add the new `.zip.o` to
   `zipos_test`'s link deps in the same file so it ships inside the
   test binary. This is the only build change; no other target is
   touched.
6. **In `test/libc/runtime/zipos_test.c` — add
   `TEST(zipos, storedRecycleConcurrent)`.** A new test alongside
   `TEST(zipos, test)`, following the same 16-thread × 20-iteration
   shape but opening the STORED member added in step 5 (path
   `/zip/test/libc/runtime/prog/stored_smoke.txt`). The existing
   `TEST(zipos, test)` is unchanged — its Worker still opens
   `hyperion.txt` and gates the untouched deflate path.

Nothing else moves. The `libc/runtime` change and the tests that
gate it ship in the same PR because they cover the same primitive.
