`_work/brieftext.tl`'s builder template (and any other kind whose body
carries this sentence): render the claim's actual branch — the same
`work/<handle>/<claim>` string `worktree` creates and `gitboard-worktree`'s
verdict line prints — instead of the item id's leading characters.

Add a case to the matching `*_test.tl` asserting the rendered brief names a
branch of the `work/<handle>/<claim>` shape, and specifically that it does
NOT name a bare id prefix — so this cannot regress into printing an
identifier that happens to look plausible.
