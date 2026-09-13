`gitboard publish --plan FILE` on a format-6 transaction writes a frozen
`cosmic.literal` plan — `{head, parent_tree, changes = {{path, mode,
content | delete}}, message, author}` — after running the same fence check
`publish --execute` runs, and `gitboard publish --call N --plan FILE`
prints the Nth connector call as a literal: `github_create_tree(base_tree
= parent_tree, tree = changes)`, `github_create_commit(tree =
$create_tree.sha, parents = {head}, message)`, `github_update_ref(ref =
heads/state, sha = $create_commit.sha, force = false)`. `refresh` confirms
the result by ancestry exactly as for a shell push. This is the one thing
the single-head proof of concept promised, in the new shape and without
packs.
