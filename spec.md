## Evidence

work#71 makes `verdict request-changes`/`reject` post a marked `COMMENT` when `api.own_login` (`GET /user`) equals the PR author's login, else `REQUEST_CHANGES`, and keeps `REQUEST_CHANGES` when the own-login read fails. Under the pin carrying it (2026-09-07-81e0660) the work#73 reviewer's bounce still failed: `POST /repos/cosmic-lua/work/pulls/73/reviews: HTTP 422`. The token in this environment is a GitHub App installation token — the PR author is `claude[bot]` — and `GET /user` is not available to an installation token (it answers for a user, not an app), so `own_login` fails, the fallback keeps `REQUEST_CHANGES`, and GitHub refuses it exactly as before. The fallback that protects a real reviewer's verdict is the path an app token always takes.

## Change

`post_review` treats a 422 on `REQUEST_CHANGES` as the own-PR case: it retries once as a `COMMENT` with the same marked body, and the verdict line says which form posted (`bounce posted as a marked comment: the token cannot request changes on its own PR`). The own-login comparison stays as the first, cheaper check. `_work/ghwrite_test.tl` gains: a transport that answers 422 to `REQUEST_CHANGES` and 200 to `COMMENT` yields one COMMENT review with the marker; a transport that answers 422 to both surfaces the error. No other verb changes.

## Non-goals

No app-vs-user token detection; no change to accept's path.

## Access

cosmic-lua/work, read and write on a branch; no other repository.

## Ready when

A reviewer's `verdict … request-changes` on a PR the same token opened records the verdict on the board and posts the marked comment, with no 422 in the verdict line.
