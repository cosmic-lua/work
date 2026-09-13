**The rule (settled upstream): a Lua float always encodes to a token
carrying `.` or an exponent.** Uniform — no band check, zero included
(`EncodeJson(0.0)` becomes `"0.0"`). A value-only fix would leave type
round-trips silently lossy and the rule unstatable in one sentence.

Four steps over six files in whilp/cosmopolitan (step 3's goldens
live in three files). Line numbers re-measured 2026-08-24 at
`5bfcf79d`.

1. `third_party/lua/luaencodejsondata.c`, `SerializeNumber` (lines
   60-82), float branch: after the `DoubleToJson` call (line 76), when
   the produced string contains none of `.`, `e`, `E`, append `.0`
   (`appends(buf, ".0")` beside the existing `appends`). The integer
   branch (`lua_isinteger`, lines 64-66) is untouched. `DoubleToJson`
   itself is untouched — its single caller is line 76, and
   `DoubleToLua`/`DoubleToEcmascript` are separate converters
   (`wrapper.cc:28` and `:51`).
2. `tool/lua/test_data_formats.lua` (245 lines; sections 1-4 at lines
   13, 55, 85, 143, `print("test_data_formats: PASS")` last at 245):
   add a **section 5** in the file's existing style — an
   `-----`-ruled `-- 5. <title>` banner, bare `assert(expr, "message")`
   lines, `cosmo` already required at line 10 — before the final
   `print`, and add its one-line summary to the header comment beside
   items 1-3. It asserts:
   - the minimal repro: `x = 1.775015055792255e18` round-trips with
     `x == back and math.type(back) == "float"`;
   - `2^53` and the `2^63` vicinity round-trip by value and type;
   - `cosmo.EncodeJson(5.0) == "5.0"` and
     `cosmo.EncodeJson(0.0) == "0.0"`;
   - integers unchanged: `cosmo.EncodeJson(5) == "5"`, and
     `math.maxinteger` round-trips as an integer.
3. Update the **seven** golden assertions the rule changes. This list
   is exhaustive — every `EncodeJson` equality assertion under `test/`,
   `tool/lua/` and `third_party/lua/` was enumerated 2026-08-24 with

       grep -rn "EncodeJson" test/ tool/lua/ third_party/lua/ \
         --include=*.lua | grep -E "==" | grep -v EncodeLua

   and the seven below are the only ones whose expected token is a
   float printed without `.` or an exponent (the rest are integers,
   strings, containers, error messages, or floats that already carry
   `.`/`e` such as `1e-12`, `3.14`, `1.5`, `2.718281828459045`,
   `-2.374623746732769e+47`):

   - `test/tool/net/ljson_test.lua:61` `'9223372036854776000'`
   - `test/tool/net/ljson_test.lua:62` `'-9223372036854776000'`
   - `test/tool/net/ljson_test.lua:63` `'9223372036854776000'`
     (all three → the same spelling with `.0` appended)
   - `test/tool/net/encodejson_test.lua:22` `EncodeJson(0.0) == "0"`
     → `"0.0"`
   - `test/tool/net/encodejson_test.lua:28`
     `EncodeJson(123.456e-789) == '0'` → `'0.0'`
   - `test/tool/net/jsontestsuite_okay_test.lua:176` `'[0]'` → `'[0.0]'`
   - `test/tool/net/jsontestsuite_okay_test.lua:207` `'[0]'` → `'[0.0]'`

   These run under the redbean suite (`test/tool/net/BUILD.mk`), which
   shares `LuaEncodeJsonData` — same commit, or that lane goes red.
   Neighbouring `EncodeLua` goldens (`ljson_test.lua:65`,
   `jsontestsuite_okay_test.lua:177`'s `'{0.}'`) do not move: a
   different converter produces them.
4. `tool/net/definitions.lua`, the `EncodeJson` doc block (lines
   2319-2408, `function cosmo.EncodeJson` at 2408): add one prose
   sentence — a float always encodes with a `.` or an exponent, so
   numbers round-trip by value AND by Lua number type. No
   `@param`/`@return` change, so the annotation ratchet is unaffected.
