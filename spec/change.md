Add a boolean encoder option, `literal`, that makes `LuaEncodeLuaData`
refuse every row of the table above with a `reason`, instead of
emitting text. Four files, plus tests:

1. **`third_party/lua/cosmo.h`** — one `bool literal;` on
   `struct EncoderConfig`, commented the way `nannull` and
   `sparsenull` are (`EncodeLua only: ...`).
2. **`third_party/lua/luaencodeluadata.c`** — at each site named in the
   table's third column, when `z->conf.literal` is set, assign
   `z->reason` and `return -1` rather than appending. Reuse the
   existing `OnError` idiom; add no new traversal — the encoder already
   visits every key and value exactly once, which is the whole point of
   the option. Each `reason` names the exclusion in words a caller can
   log (`"keyword key"`, `"byte 27 in string"`, `"non-finite number"`,
   `"mininteger"`, `"non-string key"`, `"unsupported value"`,
   `"too deep"`); no format is promised beyond "a non-empty string".
3. **`tool/lua/lcosmo.c`** — read `literal` off the option table in
   `LuaEncodeSmth`, beside `sorted` (`:121-124` is the model), defaulting
   to false in the `conf` initializer at `:107-112`.
4. **`tool/net/definitions.lua`** — add the `@field` to
   `---@class cosmo.EncoderOptions` at `:93-101`, worded
   "``EncodeLua`` only: ..." like the two `EncodeJson` ones, and add the
   option to the `EncodeLua` prose list at `:2469-2530`. Same commit,
   per this repo's AGENTS.md.
5. **`tool/lua/test_data_formats.lua`** — the encoder-contract test
   file, and already registered in `tool/lua/BUILD.mk:130-131,228`, so
   cases added here need no build edit. `wc -l` is `288`; it holds 46
   `EncodeJson` references and **zero** `EncodeLua` ones, so this slice
   writes that binding's first behavioural cases there. Its
   `EncodeJson` NaN/Infinity section is the model: the same value, once
   refused under an option and once encoded without it. One case per
   row of the table above — with `literal = true` the value returns
   `nil` and a non-empty string; with the option absent the SAME value
   encodes to the SAME bytes it does today.

**Additive only.** With `literal` absent or false, `EncodeLua` must
produce byte-identical output to today and refuse exactly what it
refuses today. That is what the second half of each test case pins.
