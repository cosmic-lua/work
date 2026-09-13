- **No 3p pin changes** (`3p/cosmos/cosmos_pin.tl`, `3p/tl/*_pin.tl`)
  — the cosmos pin moved in #1395 and the tl patch rides the cosmic
  release, not a tl pin.
- **No cast edits** — 3ISPGV8z retires the coverage cast after this
  lands.
- **No release.yml changes**, and no debugging of a red release lane
  inside this slice (file it, block on it).
- **No `--baseline` regen of any ratchet** — a pin bump that moves a
  ratchet is a finding to raise, not to absorb.
