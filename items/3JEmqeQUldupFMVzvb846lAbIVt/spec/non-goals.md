Not revisiting the 405/409 split itself — that is settled. Not adding
`expectedHeadOid` to `ghwrite.enable_auto_merge`'s payload: worth doing
eventually so the guard lives at the mutation rather than at its caller, but
the CCR REST fallback has no such field, so the two paths would diverge in
strength; this item puts the check where both paths share it.
