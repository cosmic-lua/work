- Not a fix for `cosmo.http` itself — the binding's own C code was
  twice-reviewed and is not implicated by the commit range.
- Not scoped to revert `cosmo.http` — «HPFM_HEPg» is landing with this
  regression documented rather than blocked on it (user decision:
  2026-09-12), so this item is the follow-up investigation, not a
  gate on that pin.
