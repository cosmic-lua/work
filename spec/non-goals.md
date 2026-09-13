- **No contract change.** The `cosmo.*` C boundary,
  `tool/net/definitions.lua`, and every return shape, error string and
  constant are frozen. `LiteralKeyRefusal` still returns the literal
  string `"reserved word as key"` for exactly the same inputs. The
  domain `literal = true` refuses is consumed by
  `cosmic/_literal_format.tl` and pinned by
  `cosmic/_literal_format_test.tl`; a faster check that admits or
  refuses one value differently is a correctness regression in the
  corrupting direction, not an optimization.
- **Only `IsLuaKeyword`.** `IsLuaIdentifier` (`:41-50`),
  `LiteralKeyRefusal` (`:80-88`), `LiteralScalarRefusal` (`:97-115`),
  the `memchr(s, 27, n)` string scan and every `z->conf.literal` branch
  in the serializer stay as they are.
- **Do not merge the two `IsLuaIdentifier` calls.** In literal mode it
  runs twice per string key — once at `:84` inside `LiteralKeyRefusal`
  and again at `:362`/`:398` where the serializer picks bare against
  bracketed spelling. That is a real second finding, recorded here so
  it is not lost, but it changes control flow through the serializer
  and belongs to its own slice, measured after this one lands. Do not
  take it here.
- **No cosmic-side change.** No pin bump, no type regen, no wrapper
  edit, and nothing in whilp/cosmic. The win reaches cosmic on the next
  ordinary pin bump; `_perf/bench/literal_bench.tl`'s
  `literal_format_floor_compact` row is where it will show.
- **No new test file and no new CI lane.** The equivalence check below
  goes into the existing `tool/lua/test_cosmo.lua`, wired already.
- **Do not touch `test/tool/net/**`.** That lane is `3IOCgCWG`'s and
  `3IOCgtWA`'s.
