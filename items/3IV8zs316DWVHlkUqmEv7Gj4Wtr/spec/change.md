`tool/net/llua.c`, the `esc == 'z'` branch of the short-string scan:
drop the `*q != '\n'` stop so the skip walks every following whitespace
byte, and rewrite the comment that made the divergence deliberate. A raw
newline not behind `\z` still ends the string, via the check at the top
of the scan. `tool/lua/test_llua.lua` pins both directions.

Carried by whilp/cosmopolitan#283 (2 files, +13/-7, head `c9583448`),
which is written, green, and open.
