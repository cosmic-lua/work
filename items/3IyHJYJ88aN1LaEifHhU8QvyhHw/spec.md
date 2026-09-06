## Evidence

`gitboard take ID --open` on a branch pushed with no commits past
`main` (2026-09-06, item YDqx_N2FC) refused with
`opening the PR failed: POST /repos/cosmic-lua/cosmic/pulls: HTTP 422:
Validation Failed` — GitHub's response body carried the cause
(`errors[0].message`: "No commits between main and 3Iy8ljyJ") and the
verdict line dropped it. The same 422 shape is what `open_pull`
already parses for its "already exists" fallback (`git grep -n '422'
-- _work/gh.tl`), so the body is read and then discarded for every
other message. `_work/api.tl`'s `error_of` (`git grep -n 'error_of' --
_work/api.tl`) formats status and path only.

## Change

`_work/api.tl` `error_of`: when the response body is JSON with a
`message` and an `errors` array, append `: <message>` and the first
`errors[].message` to the error string it returns — one place, every
caller. `_work/api_test.tl`: a 422 body with `errors[0].message = "No
commits between main and x"` → the returned error contains that
sentence; a non-JSON body → today's string.

## Non-goals

No retry, no change to the already-exists fallback.
