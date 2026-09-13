Semantic search for `find` (lexical FTS stays the `find` engine);
storing anything embedding-derived in the truth store
(`refs/heads/items/*` — `vectors` lives only in the derived
`o/board.db` cache); auto-merging or auto-closing suspected duplicates;
choosing or hard-coding a specific embedding provider/model in this
spec — that is an implementation decision the builder records against
whatever `GITBOARD_EMBED_MODEL` names, not fixed here.
