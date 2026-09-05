## Evidence

Neither cosmic nor cosmopolitan has a git plumbing module today: `ls
cosmic/ | grep -i git` is empty, `cosmic --docs git` finds nothing
(2026-09-05), and `cosmic --make`/`fetch` shell out to ad hoc `git`
invocations rather than a shared library. The only such library in the
ecosystem is `cosmic-lua/work`'s internal `_work/refs.tl` (254 lines)
and `_work/gitobj.tl` (266 lines) — gitboard's own git-object and
git-ref plumbing.

Both are already fully general: `grep "^local.*require"
_work/refs.tl _work/gitobj.tl` shows only `cosmic.child`, `cosmic.codec`
and `cosmic.env` — no `_work.*` cross-dependency at all, unlike
`_work/ksuid.tl` which at least named "for work items" in its header.
Nothing in either file's logic is item- or board-specific:

- `refs.tl`: `for_each_ref` (batched `for-each-ref` over glob patterns),
  `committer_date_unix`, `update_ref` (single-ref compare-and-swap),
  `is_ancestor`, `push_atomic` (one atomic multi-ref push, all-or-nothing),
  `fetch_prune`, `ensure_refspecs`.
- `gitobj.tl`: `hash_object`, `tree_of`, `mktree`, `commit_tree` (with
  independent author/committer identities and a trailer),
  `cat_file_batch` (many objects' content in one `git cat-file --batch`
  process rather than one process per object), `parse_tree`.

Test coverage differs between the two: `gitobj_test.tl` unit-tests
`gitobj.tl` directly (9 cases). `refs.tl` has no standalone
`refs_test.tl` — it's exercised indirectly through `store_test.tl`,
`storeref_test.tl` and `githold_test.tl` — real coverage, but nothing a
port could lift as a self-contained test file; new direct tests would
be needed.

## The design question this item must settle

Both files together are 520 lines — over the 500-line single-file cap —
so this lands as a directory the way `cosmic/fs/` does (`init`, `path`,
`ops`, ...), not one `cosmic/git.tl`. Pick the split (`cosmic/git/refs.tl`
+ `cosmic/git/objects.tl` is the obvious first guess; confirm against
the actual line counts once ported, since Teal's stricter records may
grow them).

More importantly: this wraps the `git` BINARY via `cosmic.child`, not a
linked library the way `cosmic.sqlite` wraps a real C library — a
`cosmic.git`-using artifact depends on `git` being present on the
target's `PATH` at runtime, which is real tension with cosmic's
self-contained-binary mission and worth naming plainly in the module's
own docs rather than glossing over. This item should settle whether
that caveat is acceptable as-is (cosmic already assumes `git` for its
own `--make fetch`) or whether the module needs a startup check
(`cosmic.git.available()`-style) that fails loudly and by name rather
than as a generic "git: command not found" from a spawned child.

## Change

1. `cosmic/git/refs.tl` and `cosmic/git/objects.tl` (or whatever split
   the line counts settle): port `_work/refs.tl` and `_work/gitobj.tl`
   near-verbatim — same function shapes, same fallible-return contract
   (`value | nil, string`) — generalizing doc comments away from
   "item"/"board" framing into plain git vocabulary.
2. `cosmic/git/init.tl`: the module's entry point and doc header,
   following `cosmic/fs/init.tl`'s convention for a directory module.
3. Tests: port `gitobj_test.tl`'s 9 cases; write new direct tests for
   `refs.tl`'s functions rather than relying on borrowed coverage from
   gitboard's own store tests.
4. `cosmic/git/git_example.tl` (`Example_*`): a short runnable example —
   reading a ref, writing a blob/tree/commit, an atomic multi-ref push
   against a local bare repo.
5. `cosmic --docs` entries for the new module and its functions.
6. Settle and document the `PATH`-dependency question above.

## Non-goals

A full libgit2-style reimplementation (parsing packfiles, its own
object database) — this stays a thin, typed wrapper over shelling out to
`git`, exactly like the code it is ported from; migrating
`cosmic-lua/work`'s own `_work/refs.tl`/`gitobj.tl` onto the published
module — a separate, later item once this stabilizes, the same
sequencing «Bb5n_SBqt» used for `_fuzz`; changing any function's
contract from what the ported code already proves.
