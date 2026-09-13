Not changing `Fetch`'s return shape, error kinds, or the `proxy` option's
format — this is environment resolution only, and the fallible-tuple
contract is untouched. Not adding proxy authentication beyond the
`user:pass@host` form the option already supports. Not changing
`SSL_CERT_FILE`/`SSL_NO_SYSTEM_CERTS` handling.
