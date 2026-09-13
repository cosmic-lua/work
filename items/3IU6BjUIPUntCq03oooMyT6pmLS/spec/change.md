In every `*_test.tl` under this batch's scope, delete each line
matching exactly `^test_[A-Za-z0-9_]*()$` — a bare call at column 1,
no arguments. Nothing else changes in those files, and no file outside
the scope is touched.

The edit is mechanical; do it with a throwaway script run from the
repo root, kept OUT of the tree (a `*.tl` inside it joins the build
graph):

```
ls cosmic/*_test.tl | awk '$0 >= "cosmic/stream_test.tl" && $0 <= "cosmic/zip_test.tl"' | xargs sed -i -E '/^test_[A-Za-z0-9_]*\(\)$/d'
```

If a ratchet gate complains, run exactly the regen command its failure
message prints and commit the result — never weaken a gate another
way.
