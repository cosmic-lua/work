1. `_work/item.tl`'s `Item` record: add `opener: string` — "the
   session that filed this item via `new`; `''` for an item that
   predates this field." Plain string, not a list (`builders`)/set —
   `new` runs exactly once per item, so there is exactly one filer,
   unlike `claim`'s lease (which moves) or `builders`'s audit trail
   (which accumulates across takeovers).
2. `SPEC`/`Raw` shapes (`item.tl`'s `shape.record({...})` and the
   `Raw` record beside it): add `opener = shape.optional(shape.string)`
   /`opener: string | nil`, matching `reviewer`'s existing treatment
   exactly (a plain optional string, no list-splitting).
3. `decode`: `opener = raw.opener or ""`, same line shape as
   `reviewer = raw.reviewer or ""`.
4. `encode`: `if (it.opener or "") ~= "" then t.opener = it.opener end`,
   same shape as the existing `repo`/`base`/`reviewer` lines — zero
   value omitted, so an item with no recorded opener (created before
   this field, or via a path that legitimately sets none) writes no
   `opener` key at all, and the file diff for every future `new` shows
   exactly the one new line.
5. `_work/gitgraph.tl`'s `cmd_new`: takes the filing session (resolved
   the same way `cmd_take`/`cmd_attach`'s callers already resolve it —
   `_work.session.resolve`, the same identity `gitboard show`'s
   "session: ... (from CLAUDE_CODE_SESSION_ID)" line already prints)
   and sets `it.opener` on the record built at line ~77, alongside
   `id`/`title`/`parent`/`repo`. No new refusal: an item files
   successfully with an empty `opener` exactly as today if the calling
   process has no resolvable session identity — `opener` follows
   `claim`'s existing "empty is a valid, meaningful value" precedent,
   not `repo`'s new required-ness (a separate item, `HlNE_YWL2`, not
   this one).
6. `_work/gitboard.tl`'s CLI dispatcher: no new flag — `opener` is
   derived from the caller's own resolved session exactly like `take`'s
   default session, never supplied explicitly, so `new` cannot be used
   to claim authorship on another session's behalf.
7. Tests (`_work/item_test.tl`, `_work/gitgraph_test.tl`): `new`
   sets `opener` to the calling session's resolved identity; an item
   decoded from a file with no `opener` key gets `""`, not a decode
   failure (backward compatibility with every existing item file);
   `encode` round-trips a set `opener` and omits an empty one, matching
   `reviewer`'s existing round-trip test shape.
