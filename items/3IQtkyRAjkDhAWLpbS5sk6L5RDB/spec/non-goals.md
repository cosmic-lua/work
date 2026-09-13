- No consumption of census follow-ups — each later contract fix gets
  its own pin-bump slice or rides a scheduled one.
- No D23 edit: the rule ("assert an unreachable binding nil, with the
  comment") stays licensed; its instance count falling to zero here is
  the outcome, not a doctrine change. `docs/decisions/**` untouched.
- No `3p/tl` changes, no `tl_patch.tl` changes.
- No other `cosmo.*` call-site changes beyond the six assert sites —
  the latent-nil sweeps own their sites.
