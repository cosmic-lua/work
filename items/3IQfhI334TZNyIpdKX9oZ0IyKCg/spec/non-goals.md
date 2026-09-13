- **`cosmic/embed/init.tl` untouched** — the Evidence paragraph is the
  record; the generated wrapper's script-level assert is correct where
  it runs. (A lexer-aware assert lint that skips string constants is
  board item 3IRTkNx1, split from this one.)
- **No behavior change on the production path**: the forked child
  already listens before serving, so the lazy-listen failure return is
  exercised only by direct `serve_forever()` callers.
- **The `-- assert:` lint is not this slice's** — 3IRTkNx1.
- **No signature change to `listen`/`accept`/`handle`** — they are
  already honest.
