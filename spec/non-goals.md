No message change for genuinely multi-statement input (its diagnosis
is right); no parser — the machine recognizes exactly the one DDL
shape that embeds statements; no bind/stmt_cache signature changes
(both callers keep the same boolean).
