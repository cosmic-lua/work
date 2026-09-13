- Not re-opening batches 2 or 3 (`appendvfs`, `completion` from batch
  1 are unaffected and still land cleanly once this resolves).
- Not deciding whether `dbdata`/`base64`/`base85` get registered by
  any per-connection API — same non-goal as the rest of `h38H_4UJ0`.
- Not fixing `db_register_extension`'s `SQLITE_OK_LOAD_PERMANENTLY`
  handling (see the separate item this research raised, below) — that
  blocks the batch-1 landing PR's own gate but is a distinct defect in
  `tool/net/lsqlite3.c`, not in the extraction rule this item answers.
