`scope` is explicitly NOT fixed here. Checked against the current `main`
tree:

```
$ grep -n 'type Options' -A 10 cosmic/sandbox/init.tl
local record Options
  fs: Fs
  sys: Sys
  net: Net
  best_effort: boolean
  allow_unenforced: boolean
  strict: boolean
  no_new_privs: boolean
end

$ grep -rn 'scope' cosmic/sandbox/
(no output)
```

`Options` has no `scope` field at all yet, and no `scope` reference
exists anywhere under `cosmic/sandbox/` — PR #1600 (item `3I7LKuM2`,
handle «X8Ro_I6Dl»), which introduces it, has not landed on `main`. Do
not add `scope` handling to `merge()` speculatively against a shape that
might still change in review. Once #1600 merges, re-verify (with the
same kind of `merge()` probe used above, against the landed `scope`
field) whether the identical drop applies and, if so, fix it as its own
follow-up — do not assume this Change already covers it.
