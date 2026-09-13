- Registers nothing; no per-connection API.
- No change to `zipfile`'s unconditional registration.
- No new third-party code.
- Not exposing `backup` or `recover` some other way (e.g. a bespoke
  API surface outside the registry) — that is a new question for
  whoever wants it, not this item.
