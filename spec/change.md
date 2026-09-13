Two things, whichever is true once investigated:

1. If gitboard CAN reach a working REST-only path here (e.g. `gh api
   repos/{owner}/{repo}/pulls/{n}` with a PATCH/PUT that doesn't
   require the GraphQL mutation the 403 names, as the error message
   itself suggests — "Use REST via `gh api`..."), fix the landing step
   to use it instead of the refused GraphQL call.
2. If no such path exists from gitboard's own pinned token in this
   class of environment, `help verdict`'s "falling back to auto-merge
   when GitHub refuses one directly" should say plainly that this
   fallback can itself be refused for session-scope reasons distinct
   from `c77H_v0vS`'s repo-setting gap, and name the recovery: the
   orchestrating session completes the landing with its own broader
   GitHub tool access, then nothing further is needed — `verdict`
   already recorded the judgment per `eWXR_dtJc`.
