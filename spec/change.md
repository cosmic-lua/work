Three files, eight casts, every shape below validated by a type-checked
implementation pass against `c2ae0466`. Six close outright; `bind.tl`'s
fallthrough and `extras.tl`'s two pcall sites keep a cast with a truer
reason, each named at its bullet.

**`cosmic/sqlite/bind.tl` (2 casts).**
- `:50` — `if v is Blob and getmetatable(v) == blob_mt as any then
  return raw_stmt:bind_blob(i, v.data) end`. The `is Blob` is only the
  narrowing the `.data` index needs; the metatable identity test still
  decides, so a plain `{data = ...}` table is rejected exactly as today
  (the module header at `:20–21` freezes that). The existing
  `-- cast: metatable identity compare` on `blob_mt as any` is not a
  `from any` cast and is untouched.
- `:52` — guard the whole declared contract of `lsqlite3`'s `bind`
  (`string | number | boolean | nil`, `o/_types/types_gen/cosmo/lsqlite3.d.tl:256`):
  `if v == nil or v is string or v is number or v is boolean then return
  raw_stmt:bind(i, v) end`. **The fallthrough keeps a cast, with the
  truer reason.** Today an out-of-contract `v` (a table, a function)
  reaches the C `bind` and raises; binding NULL instead would silently
  widen exactly the failure `3IOHOiGM` is open about. So the last line
  stays `return raw_stmt:bind(i, v as string)` under
  `-- cast: out-of-contract value, passed through so the binding raises
  as it does today`. `bind.tl` therefore ends at `from any` = 0 and 5
  casts, not 4.

**`cosmic/sqlite/extras.tl` (4 casts; 2 close, 2 keep a truer reason).**
- `:44` — `if not (db_any is Db) then return end` at the top of
  `attach`, then use `db_any` directly in place of `db`. One
  `type(x) == "table"` test; the `Database` under construction always
  passes it. The doc comment at `:41–43` explaining why the parameter is
  `any` stays, since Q2 confirms the reason still holds.
- `:32` — in `rollback_reason`, replace `return (why as string) or (what
  .. " rolled back")` with `if why is string then return why end` above
  the existing `return what .. " rolled back"`.
- `:60`, `:102` — **the two casts stay** (Q5). Replace only the reason:
  drop the trailing `-- cast: from any` and put
  `-- cast: pcall slot 2 is the raised error, typed boolean from TxFn`
  on the line ABOVE each `return false, (verdict as string) or
  "transaction failed"` / `"savepoint failed"`. The expression is
  untouched, so behaviour is byte-identical and no test moves.

**`cosmic/fetch/extras.tl` (2 casts).**
- `:273` — in `verb`, replace `if opts_any then` + `pairs(opts_any as
  {string: any})` with `if opts_any is {string: any} then` and a bare
  `pairs(opts_any)`. Nil still skips the copy. **Stated behaviour
  change:** a truthy non-table `opts` used to raise inside `pairs`; it
  is now skipped, and the request goes out with only `method` set.
- `:298` — in `download`, replace `local res = res_any as StreamRes`
  with `if not (res_any is StreamRes) then return fail_make("download:
  stream returned no response") end`, then use `res_any` directly.
  `fail_make(msg: string)` is the module's own failure builder
  (declared `:285`, used at `:305` and `:348`), so the failure shape
  matches the file's existing ones.

**The ratchet.** `_build/casts_baseline.tl` counts every cast in a file,
not only the `from any` ones. Run exactly the command the gate's failure
prints — `bin/cosmic --make run _build/casts.tl --baseline` — and commit
the result. Expected row moves:

| file | row today | row after |
| --- | --- | --- |
| `cosmic/sqlite/bind.tl` | `= 6` | `= 5` |
| `cosmic/sqlite/extras.tl` | `= 4` | `= 2` |
| `cosmic/fetch/extras.tl` | `= 6` | `= 4` |

No row disappears here: all three files still carry casts after the
change (`bind.tl`'s out-of-contract fallthrough, `extras.tl`'s two pcall
sites, and `fetch/extras.tl`'s four unrelated ones).
