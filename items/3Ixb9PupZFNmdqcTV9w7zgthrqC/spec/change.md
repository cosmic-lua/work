`gitboard take ID --open [--body FILE]`: the orchestrator's handover
for a diff whose PR does not exist yet. gitboard opens the PR and then
records it exactly as `--pr N` does today.

- `_work/api.tl`: `api.call` accepts a fourth argument, `body: string |
  nil`; when non-nil it is sent as the JSON request body with
  `content-type: application/json`, and the ETag cache is neither read
  nor written for that call (rate accounting unchanged). `api.tl:4`'s
  doc sentence changes to state the read/write split. No other caller
  changes.
- `_work/gh.tl`: `open_pull(s, repo, head, base, title, body): integer
  | nil, string` — `POST /repos/<slug>/pulls` with `{title, head, base,
  body, draft = false}`; returns the new number, or the API error
  through the existing `api.error_of`. A 422 whose message says a PR
  already exists for the head resolves by `GET
  /repos/<slug>/pulls?head=<owner>:<head>&state=open` and returns that
  number instead — idempotent, so a retried `--open` never opens a
  second PR.
- `_work/gittake.tl`: `--open` computes head = the id's first 8
  characters (the branch `take` names), base = the item's `base`, title
  = the item's title, body = `Board: <full id>` + blank line + the
  contents of `--body FILE` when given (the builder's description
  paragraph, pasted from its report) and nothing else. Refuses on the
  verdict line, without calling GitHub, when: the claim is not the
  caller's (same rule as `--pr`), `--pr` is also given, the item has no
  `repo`, or `git ls-remote` of the item repo shows no such branch —
  name the branch in the refusal. On success the verdict line is the
  same as `--pr N`'s with the number gitboard obtained: `<id8> is yours
  pr:N — awaiting review`.
- `_work/gitcommands.tl`: the two options on `take`.
- `_work/brieftext.tl`, builder template steps 7–9: step 8 becomes
  "Do not open a PR. Your final report carries the branch name and one
  paragraph describing what changed and why, written for the PR body —
  the orchestrator opens the PR with `gitboard take ID --open`." Drop
  the `gh`/MCP mechanism sentence #44 added there; keep the no-poll
  sentence. `gitboard help orchestrate`'s reconcile bullet
  (`_work/doctrine.tl`): "Finished with a pushed branch: `take ID
  --open --body FILE`" beside the existing `--pr N` line.
- Tests: `_work/gh_test.tl` (84 lines) — `open_pull`'s request shape
  (method, path, decoded body fields) and the 422-already-exists
  fallback, through whatever seam `api.tl` gains for a fake transport
  (a module-level `M.transport` the tests replace is enough — the same
  shape `cosmic.fetch` callers use elsewhere in `_work`; measure before
  choosing). `_work/gittake_test.tl` (93 lines): `--open` with `--pr`
  refuses; no `repo` refuses; the body's first line is `Board: <id>`.
  `_work/brieftext_test.tl`: the builder brief no longer contains
  `create_pull_request` and does contain `take ID --open` (update the
  case #44 added).
