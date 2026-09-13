- No binding change. Every value asserted (CRC checksums, base64/base32
  vectors, deflate byte output) is a fact about the fork's CURRENT,
  frozen behavior; a mismatch is evidence to fix the ASSERTION to match
  reality, never the binding.
- Do not touch `test/tool/net/**` or `test/tool/BUILD.mk`; retirement is
  `3IOCgtWA`.
- Do not touch `tool/lua/test_definitions_conformance.lua`; this slice
  adds a second, complementary layer (value correctness) alongside its
  existing type-truthfulness layer, and does not replace it.
