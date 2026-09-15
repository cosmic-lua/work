`drop` (and any claim-boundary verb) must refuse BEFORE it composes when an
unpublished item-mutation composition is already pending, instead of
composing a mixed snapshot that nothing can then publish.

Reproducer, on gitboard 2026-09-15-3fd0445:

```
gitboard new "..." --parent <ID> --spec-file F   # prepares d19c07f7, unpublished
gitboard drop <ID> --why "..."                   # "claim acquisition/release is a
                                                 #  separate publication boundary"
```

The `drop` prints that refusal, but it has ALREADY rewritten
`refs/gitboard/snapshot` to a commit carrying both the `new` item files and
the claim deletion (verified: `git diff --stat <state> <snapshot>` showed
`claims/<ID>` deleted plus the new item's `meta`, `spec/change.md`,
`spec/non-goals.md`). From that point every verb returns the same one line
and nothing else:

- `gitboard snapshot` — refuses, so the composition cannot even be inspected
- `gitboard snapshot --check` — refuses, and exits 0 while doing so
- `gitboard publish <new-commit>` — "a different local snapshot proposal already exists"
- `gitboard publish <mixed-commit>` — refuses with the boundary message

The only exit is `gitboard snapshot --abandon <mixed-commit>`, which the
refusal never mentions. A session that does not already know that verb is
wedged with no path forward and no diagnostic naming one.

A SECOND instance of the same shape, same session, different verb:

```
gitboard new "..." --spec-file F        # prepares, unpublished
gitboard attach <NEW> <PARENT>          # "read: no such item: <NEW>"
```

`attach` resolves its argument against the PUBLISHED board, so an item
still sitting in the local composition does not exist to it. It printed
that refusal — and composed the attach anyway. The snapshot commit
advanced (`a5858c45` to `40deeb3f`), and after publishing, `show` reported
the item already carrying the intended parent, while a second `attach`
answered `nothing to record: ... leaves the board unchanged`. The refusal
was cosmetic; the mutation landed. Here it happened to land the RIGHT
edge, which is worse, not better: the same path could as easily compose an
edge the caller was told was rejected.

Two defects, both in scope:

1. The boundary check runs after composition rather than before it. Move it
   ahead of the write so a refused `drop` leaves the pending composition
   untouched.
2. `snapshot` (bare and `--check`) must always be able to INSPECT the
   composition — a verb whose whole job is to show local state should not be
   gated by the boundary rule it is being used to diagnose. `--check`
   additionally exits 0 on this refusal; a refusal must not exit 0.

Add regressions covering: a `drop` refused for a pending item mutation
leaves `refs/gitboard/snapshot` byte-identical; bare `snapshot` renders a
mixed composition rather than refusing; and `snapshot --check` exits
non-zero when it refuses.
