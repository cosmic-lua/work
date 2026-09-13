`tool/net/definitions.lua`, the `unix.localtime` (and, if it carries
one, `unix.gmtime`) doc-comment example: replace the positional row
with the table the binding returns now, matching the example
`tool/net/help.txt` carries after #339. No annotation change; the
coverage ratchet must stay green (`make -j$(nproc) o//tool/lua/test`).
