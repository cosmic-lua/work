Rewrite `tool/net/demo/unix-dir.lua:77`'s destructuring to read the
new `unix.BrokenDownTime` table's fields (`.year`, `.mon`, `.mday`,
`.hour`, `.min`, `.sec`, `.gmtoffsec`, ...) instead of positional
locals, and update whatever the demo does with those values
accordingly (read the surrounding function body first — the fix
should preserve the demo's existing behavior/output, not just make it
not crash).
