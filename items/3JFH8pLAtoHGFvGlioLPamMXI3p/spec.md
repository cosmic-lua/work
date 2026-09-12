## Change

`_work/gitwrite.tl`'s `Request` carries two fields no caller anywhere in
the tree ever sets:

```
$ grep -rn 'extra_commits\|drop_held' --include=*.tl .
./_work/gitwrite.tl:54:  drop_held: {string: boolean}
./_work/gitwrite.tl:61:  extra_commits: {fastimport.CommitPlan}
./_work/gitwrite.tl:115:  if (req.drop_held or {})[it.id] then
./_work/gitwrite.tl:139:--- `refs/heads/board/seq` too, plus every one of `req.extra_commits`,
./_work/gitwrite.tl:172:  for _, c in ipairs(req.extra_commits or {}) do
```

Every hit is inside `gitwrite.tl` itself: the fields are declared, each
is read in one branch, and `storewrite.save` — the only builder of a
`Request` — sets neither. Their doc comments name `gitboard migrate` as
the caller (`gitwrite.tl:58`, `:166`), and that verb is gone: README
says the format-3 to format-4 migration has been retired, and
`_work/format_test.tl:41` actively asserts the refusal no longer
mentions it. So `save_batch`'s `extra_commits` loop and `plan_one`'s
`drop_held` branch are unreachable code carrying documentation that
describes a caller which does not exist.

Decide which of the two this is, and make the tree say so:

1. **A hook the next migration needs.** `extra_commits` is exactly the
   shape a format bump wants — item refs and the format ref moved in one
   atomic push — and a format-5 migration is a filed item. If it is
   kept, its doc comments must stop naming a retired verb and say
   instead that it is an unused hook, what shape a caller passes, and
   which item is expected to become that caller. Unreachable code with
   no test is unreachable code that has never been proven to work; a
   kept hook needs a test that exercises the loop and the branch, or it
   is not a hook, only a plan.
2. **Dead weight to delete.** Both fields, both readers, and the doc
   paragraphs go, and the migration rebuilds what it needs against the
   shape it actually wants rather than against a guess made before it
   was written.

Either way the outcome is that no reader of `gitwrite.tl` is told about
a caller that was removed.

Whichever is chosen, record the reasoning in the commit message: the
next person to find these fields will ask the same question, and the
answer is cheaper to read than to re-derive.

## Non-goals

Changing what `storewrite.save` writes, or any commit shape the board
emits today. Both branches are unreachable, so neither choice can move
a byte of what any current verb produces — a diff that changes an
existing commit's content means the change went wrong.

Deciding the format-5 migration's own design. This item settles whether
`gitwrite` keeps a hook for it, not how the migration works; if the
answer is "keep", naming the migration item is enough.

Auditing the rest of `_work` for other unreachable code. This is one
concrete finding with one concrete decision, not a sweep.
