Six files in whilp/cosmopolitan. No cosmic-side file is touched.

**1. `tool/net/llua.h`** (new, ~15 lines) — mirror `tool/net/ljson.h`:

```c
#define LLUA_ERRMAX 256
struct DecodeLua {
  int rc;
  const char *p;
};
struct DecodeLua DecodeLua(struct lua_State *, const char *, size_t, char *,
                           size_t);
```

`rc` is 1 when one value was pushed, 0 for eof, -1 for an error. On
success `p` is the rest of the input, exactly as `DecodeJson` returns
it. **On -1, `p` points at the FAILING BYTE of the input** and the
message is written into the caller's buffer (the last two arguments).

That buffer is the one deviation from `DecodeJson`'s signature, and it
is deliberate. `DecodeJson` returns a STATIC message in `p`, which
cannot carry a key name; the duplicate-key refusal must. Pushing the
message onto the Lua stack instead would be worse, not better: the
parser may hold partial tables on the stack when it fails, so the
caller has to `lua_settop` back to its entry depth, which would
discard the message it was about to read. A caller-supplied buffer is
reentrant, keeps the struct pure C, and keeps the error path away from
the stack entirely. `LLUA_ERRMAX` is 256 and the message is truncated
to fit — a key longer than the buffer is truncated in the message
only, never in the refusal itself.

Reporting a byte OFFSET rather than a line is what keeps line-counting
out of the hot loop: the offset is free because the parser already
holds the cursor, and the Lua side counts newlines up to it once, on
failure.

**2. `tool/net/llua.c`** (new, ~620 lines) — the parser, in one pass,
recursive descent, no token stream. Shape it as the skeleton above:
constants (`DEPTH 32`, `MAXCODEPOINT 0x7fffffff`), the sorted
22-entry keyword table, then `IsLongBracket`, `LongBracketEnd`,
`SkipTrivia`, `ScanShortString`, `ScanLongString`, `ScanNumber`,
`FirstKeyAt`, `ParseTable`, `Parse`, `DecodeLua`. Rules:

- **Classify with `libc/ctype.h`** (`isalpha`, `isalnum`, `isdigit`,
  `isspace`), not a bespoke 256-byte table.
- **Numbers**: scan the numeral's SHAPE per `_literal_lex.tl`'s
  `numeral_at`, then hand the text to `lua_stringtonumber`
  (`third_party/lua/lua.h:354`). A shape `lua_stringtonumber` rejects
  (`0x.`, `1e`) is the "malformed number value" refusal, exactly as
  the Teal reader's `tonumber` check is.
- **Depth**: `DEPTH 32`, matching the reader, AND the real C stack
  guard `ljson.c` uses (`GetStackPointer() < bsp`). Neither is an
  option and neither is caller-supplied.
- **Duplicate keys**: refuse. Detect with `lua_rawget` before the
  `lua_rawset`; on a hit call `FirstKeyAt`, which re-scans the
  enclosing table's entries from its opening `{` for the first entry
  naming that key. That re-scan is COLD — it runs only to compose the
  refusal — so no table pays a shadow map for it. The message is
  `snprintf`ed into the error buffer as
  `repeats the key '%.*s' (first at offset %d)`; every other message is
  a distinct static string copied into the same buffer, one per refusal
  class, and reproducing cosmic's wording is the sibling item's job.
- **`\u{...}`** is bounded at `0x7FFFFFFF` and encoded as UTF-8 (up to
  six bytes), matching `utf8.char`; above the bound is a refusal, not
  a truncation.
- Keep the fork mergeable: a new file plus the entries below, and no
  edit to any neighbouring file's existing lines.

**3. `tool/lua/lcosmo.c`** (~35 lines added) — `LuaDecodeLua`,
modelled on `LuaDecodeJson` (`tool/lua/lcosmo.c:44-79`), plus one
`{"DecodeLua", LuaDecodeLua}` entry in the registration table beside
`{"EncodeLua", …}` at `:230`. It returns the value on success, and on
failure `nil, message, offset`, where it owns the `char
errbuf[LLUA_ERRMAX]` it passes down and `offset` is `r.p - p` as a
1-based byte index. Slot 2 stays the message, so cosmic's
fallible-returns shape is unaffected: the wrapper reads three and
returns two. `#include "tool/net/llua.h"` beside the `ljson.h`
include. Measured headroom: `tool/lua/lcosmo.c` is 346 lines and this
repo imposes no per-file cap.

**4. `tool/net/BUILD.mk` and `tool/lua/BUILD.mk`** — one
`o/$(MODE)/tool/net/llua.o` line beside the `ljson.o` line in each
(`tool/net/BUILD.mk:102`, `tool/lua/BUILD.mk:31`); a two-line
`o/$(MODE)/tool/lua/test_llua.ok` rule in the style of
`tool/lua/BUILD.mk:129-130`; and one `test_llua.ok` entry in
`TOOL_LUA_TESTS` (`:217`).

**5. `tool/net/definitions.lua`** (~15 lines added, same commit) —
the `cosmo.DecodeLua(source)` annotation block beside
`cosmo.EncodeLua` at `:2505`, with full `@param`/`@return` for all
three returns. The coverage and conformance ratchets in
`o//tool/lua/test` fail otherwise, and that is the gate.

**6. `tool/lua/test_llua.lua`** (new, ~250 lines) — registered as
above. Its core assertion is the module's actual contract, and it is
self-contained because `load` is in the same process:

- **agreement with `load`**: a table of source strings, each asserted
  to deep-equal `load(s)()`. Cover, at minimum: a flat table of
  strings and integers (the `*_pin.tl` shape); a nested table (the
  `.cosmic-coverage` shape); a leading `#!` line; `--` line comments
  and a `--[==[ … ]==]` long comment; a level-5 long bracket whose
  BODY contains `--[[` and `]]` (the `tl_patch.tl` shape); both quote
  forms; every escape form including `\z`, `\xHH`, `\011`, and
  `\u{...}` at the bound; negative numbers, hex numerals, hex floats
  with a `[pP]` exponent, decimal exponents; `["key"] =` and
  `name =` entries; `,` and `;` separators; `true`/`false`.
- **the byte sweep**: for `b = 0, 255`, `DecodeLua(string.format('return {x = %q}', string.char(b) .. "0"))` equals
  `load` of the same source. This is the sweep that caught the blocker
  on the Teal side.
- **the refusal classes**: one case per class from Evidence, each
  asserting `nil`, a message DISTINCT from every other class's, and
  the expected byte offset. Include a `["a"]=1, a=1` duplicate whose
  message names the key and the first offset, a 33-deep nesting, and
  `return { end = 1 }`.
