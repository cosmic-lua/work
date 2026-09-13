1. `_build/doc_returns_test.tl` (new, `--- reads:` the tree's built index
   `o/embed/cosmic/.docs/index.lua` and `cmd/cosmic/embed_gen.tl`): over every
   non-internal `cosmic.*` module's `functions`, for each function with at least one
   `@return` tag, the tag count equals the signature's top-level return-slot count
   (the `slots` walk above, moved into `_tool/doc/exports.tl` or a sibling under the
   cap as `return_slots(signature): integer` with its own unit test: `boolean,
   string` → 2, `{string: any} | nil, string` → 2, `function(Entry): (WalkAction, T)`
   → 1, no return → 0). A function with NO `@return` tags is not judged (a bare-value
   infallible function documents its value in prose today; requiring tags everywhere
   is a different, larger change). Message: `<module>.<name>: <n> @return tags,
   <m> declared slots — <signature>`.
2. The same test normalizes the `?` spelling: a tag `@param name?` and a signature
   `name?:` are the same parameter; a tag naming a parameter the signature lacks
   fails with `<module>.<name>: @param <p> is not a parameter of <signature>`.
   Measured zero such cases once `?` is normalized, so this lands green.
3. Fix the nine in the same PR: add the error-slot `@return string` tag each is
   missing (for `execve`/`execvp`/`execvpe`, whose slot 1 is `nil` on the only path
   that returns, the first tag documents that slot as "nil — the exec did not
   happen"). Doc-comment edits only.
4. `_tool/doc/init.tl`'s `parse_annotations` is untouched: the tags are read as they
   are; the gate compares.
