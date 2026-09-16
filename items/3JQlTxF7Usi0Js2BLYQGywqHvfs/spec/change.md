`gitboard help orchestrate` says agents never run board verbs, and the builder
brief's last step says the same, but every review posture in
`_work/brieftext_review.tl` (diff, script, research, rework) instructs the
reviewer under "Recording your verdict" to run `verdict` through
`{{.gitboard_cmd}}`, which renders as the unresolved-invocation sentinel
whenever the caller passes no `--gitboard-command`. Make the emitted text
consistent with the doctrine:

1. In each review posture's "Recording your verdict" section, the reviewer
   does not run `verdict`. It ends its final report with one verdict line in
   a fixed envelope, `verdict: accept|request-changes|reject head=<sha>
   session=<review session>`, followed by its findings; the caller records it
   with `verdict ID KIND --head SHA --session S`. Keep the "never poll or
   subscribe" sentence, the sentence saying the caller owns landing and
   `done`, and the review session string (the envelope carries it). Remove
   every `{{.gitboard_cmd}}` rendering from the review postures.
2. Builder step 6 in `_work/brieftext.tl` likewise stops rendering a `take`
   command line: the builder reports the exact commit id and the caller runs
   `take`. No `{{.gitboard_cmd}}` renders in any builder brief.
3. `help review` in `_work/doctrine.tl`: the sentence saying the reviewer's
   session "records the verdict itself" now says the reviewer reports the
   envelope and the caller records it under the review session.
4. Regenerate the committed renderers under `_work/brieftmpl/`. Update
   `_work/brieftext_test.tl` and `_work/brief_test.tl` where they pin the
   old verdict command lines (the sentinel-in-verdict-command assertion and
   the checkout-free script verdict test included) so they assert the
   envelope instead, and add one assertion per posture that no rendered
   review or builder brief contains the sentinel or the string `verdict
   {{.item_id}}`.

`brief`, `handoff` and `worktree` keep accepting `--gitboard-command` and
`--gitboard-cwd`; the value simply no longer renders in a brief body.
