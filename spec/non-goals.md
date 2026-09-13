- Not implementing any binding work in cosmic-lua/cosmopolitan from
  this repo — that upstream C-layer change is cosmic-lua/cosmopolitan#144
  and lives entirely in that repo.
- Not stubbing partial IPv6 support ahead of the binding (e.g., parsing
  v6 literals but refusing to dial them) — the issue's own design
  explicitly makes `Addr` a single currency extended by value, and a
  parse-only half-step would need its own throwaway migration once
  the real binding lands, which is waste this spec does not propose.
- Not re-filing or duplicating cosmic-lua/cosmopolitan#144 itself.
