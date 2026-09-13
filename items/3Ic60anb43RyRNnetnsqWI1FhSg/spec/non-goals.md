No change to the 304 protocol, cache keying, or freshness logic. No
cache format migration handling beyond treating old entries (missing
the field) as misses — they repopulate on the next fetch.
