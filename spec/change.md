Two new files, both with the same prelude aliasing every bare name
they use to its `cosmo.*` binding (no submodule needed — all of these
are top-level `cosmo.*` functions):

```lua
local cosmo = require("cosmo")
local unix = require("cosmo.unix")
local EncodeBase64, DecodeBase64 = cosmo.EncodeBase64, cosmo.DecodeBase64
local EncodeHex, DecodeHex = cosmo.EncodeHex, cosmo.DecodeHex
local EncodeBase32, DecodeBase32 = cosmo.EncodeBase32, cosmo.DecodeBase32
local EscapeHtml, EscapeParam, UnescapeParam = cosmo.EscapeHtml, cosmo.EscapeParam, cosmo.UnescapeParam
local IsValidPercentEncoding = cosmo.IsValidPercentEncoding
local DecodeLatin1, EncodeLatin1 = cosmo.DecodeLatin1, cosmo.EncodeLatin1
local ParseUrl, ParseIp = cosmo.ParseUrl, cosmo.ParseIp
local GetMonospaceWidth = cosmo.GetMonospaceWidth
local IsPublicIp, IsPrivateIp, IsLoopbackIp = cosmo.IsPublicIp, cosmo.IsPrivateIp, cosmo.IsLoopbackIp
local FormatHttpDateTime = cosmo.FormatHttpDateTime
local Crc32, Crc32c = cosmo.Crc32, cosmo.Crc32c
local Deflate, Inflate = cosmo.Deflate, cosmo.Inflate
local EncodeLua = cosmo.EncodeLua
```

(`base64_test.lua` needs only the first line of aliases plus
`unix`; `lfuncs_test.lua` needs the rest.)

| source | destination |
|---|---|
| `test/tool/net/base64_test.lua` | `tool/lua/test_base64_vectors.lua` |
| `test/tool/net/lfuncs_test.lua` | `tool/lua/test_lfuncs_values.lua` |

`lfuncs_test.lua` also asserts `Compress == nil and Uncompress == nil`
(the deprecated pair the fork removed) — keep that assertion; it is a
live, still-true contract check, aliased as `local Compress, Uncompress
= cosmo.Compress, cosmo.Uncompress` in the prelude alongside the rest.

`tool/lua/BUILD.mk:222-251` gets two new three-line rules
(`o/$(MODE)/tool/lua/test_base64_vectors.ok: o/$(MODE)/tool/lua/lua.dbg
tool/lua/test_base64_vectors.lua`, run, `@touch $@`, and the equivalent
for `test_lfuncs_values`), and two new `TOOL_LUA_TESTS` lines.
