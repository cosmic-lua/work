Delete all 13 `number to integer` casts, in six files plus one
generated-declaration correction. No other cast reason is touched.

**1. `cosmic/instrument.tl` — 7 sites, 7 → 0.** At `:111`, `:117` and
`:124-125` delete the ` as integer` and the `-- cast:` comment; the
`math.floor(...)` calls already return `integer`. At `:162-165` wrap
each with `math.tointeger`, keeping the existing zero default:

```text
exit = (math.tointeger(tonumber(exit_str) or 0) or 0),
```

and the same for `wall_ms`, `cpu_ms`, `maxrss_kb`. The trailing `or 0`
is the honest half — `math.tointeger` returns nil at runtime for a
non-integral value even though tl declares it `integer` — and it
preserves today's behaviour, which is that an unparseable field reads
as 0.

**2. `_tool/testrun.tl:112` — 1 site, 1 → 0.** Delete the cast and its
comment; leave `exit_code = (128 + r.signal)`.

**3. `cosmic/quicksand/box/run.tl:198` — 1 site, 3 → 2.** Delete the
cast and its comment; leave `bind_ip = cosmo.ParseIp("127.0.0.1"),`.

**4. `cosmic/errno.tl:119-122` — 1 site, 3 → 2.** Replace the
`is number` guard and its cast with a `math.tointeger` guard:

```text
local n = v is number and math.tointeger(v) or nil
if n then
  codes[name] = n
end
```

The `-- cast: dynamic E* lookup` on the line above stays; only the
`number to integer` cast goes.

**5. `cosmic/quicksand/proxy/serve.tl:111-116` — 1 site, 1 → 0.**
Replace the `v is number` guard with a `math.tointeger` guard so the
`%d` argument is typed:

```text
local iv = v is number and math.tointeger(v) or nil
if iv then
  table.insert(parts, string.format(',%q:%d', k, iv))
else
  table.insert(parts, string.format(',%q:%q', k, tostring(v)))
end
```

This is a deliberate behaviour change and the only one in this slice: a
non-integral number field previously reached `string.format("%d", v)`,
which raises `number has no integer representation` in Lua 5.4, and now
falls to the existing `else` branch and logs as a quoted string.

No current caller can reach that branch — every `logger.*` call in
`serve.tl` passes ports, status codes and byte counts, all integers
(`grep -n 'logger\.' cosmic/quicksand/proxy/serve.tl` lists 15 calls
at `:184`–`:392`) — so the float case gets no test and the integer
case gets a regression guard. Add one test to
`cosmic/quicksand/proxy/serve_test.tl` (206 lines today, 294 of
headroom under the 500-line cap) named
`test_json_log_writes_an_unquoted_integer_port`: start a proxy with
`log_format = "json"`, `log_level = "info"` and `log_file` pointing
into `TEST_TMPDIR`, then read that file and assert its `listen` line
matches `"port":%d+` and does NOT match `"port":"`. The `listen` event
at `serve.tl:359` is what emits it.

**6. `_types/gentl.tl:199-200` — closes 2 sites, `_tool/coverage/lines.tl`
11 → 9.** Change the curated `tl.Error` record's `y: number` and
`x: number` to `y: integer` and `x: integer`, matching upstream
`tl.tl:614-615`. Then delete both casts and their `-- cast:` comment
lines at `_tool/coverage/lines.tl:113-114` and `:120-121`, leaving
`(e.y or 0)` as the `%d` argument.

**7. Regenerate the baseline.** After the edits run
`bin/cosmic --make run _build/casts.tl --baseline` and commit the
result — that is the exact command the ratchet's failure message
prints, and it is in scope here.
