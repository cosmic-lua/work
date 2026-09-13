Amend `mWAm_RQTM`'s spec (`gitboard spec 3Idu1WF5vawzMGuNBL9mWAmRQTM`):
remove `test_response_too_large_error_message` from the self-contained group
that item ports, and fold it into the same "not ported by this slice, needs
a verified CI network policy first" bucket the spec already carries for the
`httpbin.org`/`github.com` tests. Note in that bucket that this specific test
also cannot pass until the `%I` format bug is fixed (sibling item, filed
separately) — two independent blockers, not one.
