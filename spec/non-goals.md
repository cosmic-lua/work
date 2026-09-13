- No dispatcher auto-retry: the refusal names the re-run, and
  take-mode already falls to its next candidate on any refusal. An
  automatic re-run at dispatch is its own item if friction shows.
- No change to `sync`/`rebase_onto_remote` as `cmd_sync` uses them
  (the conflicted-rebase unwind there stays).
- No transient-push-failure retry: a push that fails for any reason
  is the same refusal, and the re-run costs one command.
- No change to `save`'s one-mutation-one-commit contract — it is what
  makes the drop exact.
- No change to `wip_refusal`, `force`, or `vacated` semantics at the
  up-front gate.
- No edit to `skills/work/SKILL.md` on `main` — different branch,
  different PR, sequenced after this lands.
