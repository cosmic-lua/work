- Does not implement any binding or wrapper — that is explicitly
  deferred to the two follow-up items the record produces.
- Does not re-litigate `cosmic.hash`'s existing scope (digests, HMAC,
  Argon2 password hashing) — those stay as they are regardless of what
  this decides.
- Does not decide anything about `cosmic.tls`/cosmopolitan#143 (the
  transport-level TLS wrap) beyond noting the sequencing parallel; that
  stays its own tracked item under #500.
