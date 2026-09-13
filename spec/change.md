Rewrite `tool/net/demo/unix-info.lua:38`'s destructuring to read the
new `unix.Rlimit` table's fields (`.soft`, `.hard`) instead of
positional locals, and update whatever the demo does with those
values accordingly (read the surrounding function body first — the
fix should preserve the demo's existing behavior/output, not just
make it not crash).
