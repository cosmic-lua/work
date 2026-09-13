None. Migrating these calls to a cache handle would add a read (opening the
cache) without removing one (the mutation's own `store.list` stays,
required), making these verbs slower, not faster — the opposite of this
parent item's purpose. Recommendation from the research: resolve
not-planned citing this finding.
