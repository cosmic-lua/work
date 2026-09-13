- **Registers nothing.** Making an extension available is not making it active; the
  per-connection registration API is its own item.
- No behaviour change for `zipfile`'s current unconditional registration; that break
  belongs to the cosmic API item.
- No new third-party code — every byte here is already vendored.
