- `find_info` stays on `fs_walk.visit`: it needs `FileInfo.mode` per
  entry, which requires the stat `find_iter` deliberately skips for
  non-directories. Not touched by this change.
- `fs.visit`'s own d_type descent and a lazy `Entry.stat` — the
  expensive half of the parent hypothesis — is the sibling item
  «x5gU_h61r» (`3ILxnhaKL5YDmOKs5Tqx5gUh61r`), a different file
  (`cosmic/fs/walk.tl`) and a different PR.
- `glob` is untouched — a different capability (component-path
  expansion, never recurses) with its own contract; not part of the
  `find`/`find_iter`/`find_info` engine swap.
- `find` does not gain a documented order guarantee. It never promised
  one before this change and does not promise one after — `sorted`
  remains the only way to get one. (See "Open at refinement" below for
  why the *unsorted* order happens not to move either, which is a fact
  about this change, not a new contract.)
