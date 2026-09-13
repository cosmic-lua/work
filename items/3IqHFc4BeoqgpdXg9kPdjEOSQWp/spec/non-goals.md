Not `_build/doc_paths_test.tl` itself — its CI-fails-loud logic is
correct and unrelated to this bug; once this is fixed, #1669 should go
green with no changes on its side. Not a broader audit of what else a
non-root `builder` process can or can't read in this container — scoped
to the one credential-file permission gap this evidence identifies.
