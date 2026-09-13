`tool/net/llua.c`, the top of `ScanShortString`'s scan loop: the raw
line-terminator check `if (ch == '\n')` becomes `if (ch == '\n' || ch ==
'\r')`, so a lone carriage return fails with `kErrString` exactly as a
newline does. The `\z` skip is unaffected — `\r` behind `\z` is
whitespace `load` skips too, and `isspace` already skips it.
`tool/lua/test_llua.lua` pins the refusal and pins that `\z\r` still
skips.
