One file: `third_party/lua/luaencodeluadata.c`, in whilp/cosmopolitan.

Replace `IsLuaKeyword`'s body (`:63-73`) with a length-bucketed lookup.
Keep the function's name, signature, and its single call site at `:84`
unchanged. Keep `kLuaKeywords` (`:52-56`) exactly as it is — it is the
readable statement of the set and other readers may rely on it; add the
buckets beside it rather than replacing it.

The shape:

- return `false` immediately when `n < 2 || n > 8`, and when `n == 7`;
- otherwise compare `p` against only the keywords of length `n`, with
  `memcmp(p, kw, n)` — equal lengths make `strncmp`'s trailing
  `!kw[n]` check unnecessary, and `memcmp` needs no NUL scan;
- express the buckets as static const tables in the file, one per
  length, sized by the table above. Do not compute them at runtime and
  do not add a hash.

The result must be exactly equivalent: the same 22 strings return
`true`, everything else returns `false`. This is a pure lookup
rewrite — no behaviour, no contract, and no annotation moves.

Follow the fork's convention (AGENTS.md): a surgical diff, no drive-by
reformatting of the surrounding file.
