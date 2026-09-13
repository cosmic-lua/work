- No change to how unknown/missing options are reported
  (`result.unknown`/`result.missing` stay as-is — they are not this
  binding's nil path).
- No change to `re.*`/`argon2.*` bindings (separate captures/rows).
- No relaxing `MAX_ARGC`/`MAX_LONGOPTS` — those limits stay; only the
  channel they report through changes from a return value to a raise.
