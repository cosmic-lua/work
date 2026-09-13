`_work/ghwrite.tl`'s `enable_auto_merge`: attempt the GraphQL mutation
first, unchanged — this keeps the function correct in any environment where
GraphQL is available (a plain CI runner with an unrestricted PAT, for
instance). On a 403 whose body matches this specific proxy's refusal shape
(match on the distinguishing substring, e.g. `"GraphQL is not available
from Claude Code sessions"` — do not match on a generic 403, which has many
unrelated causes), retry via `PUT /repos/{owner}/{repo}/pulls/{n}/ccr/auto_merge`
with the same `merge_method`, parsing its `{"enabled": bool}` shape instead
of GraphQL's `errors` array. Preserve the existing `boolean, string` return
shape and error rendering for both paths.

Add fixture cases to `_work/ghwrite_test.tl` (which already fakes
`api.call`/the transport) for: the GraphQL path succeeding as today, the
GraphQL path refused with the CCR-shaped 403 and the REST fallback
succeeding, and the GraphQL path refused with an UNRELATED 403 (should NOT
attempt the CCR fallback — surface the original error instead, since that
403 is a different, real refusal a caller needs to see honestly).
