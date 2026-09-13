Add to `decompose.md`'s ready bar: when an item's `Change` REPLACES a
mechanism — a gate moving from machinery to procedure, a rule changing
what enforces it, an API's callers moving to a successor — the spec must
carry an inventory of every site asserting the old mechanism, produced
by a command, with each site marked as one of:

- **rewritten** — the diff changes it, and the spec says to what;
- **still true** — the old mechanism survives this slice (a staged
  removal), so the assertion stands, and the spec says which later item
  retires it;
- **out of scope** — with the reason.

The inventory is a command and its output, so a reviewer re-runs it and
a later session sees what was deliberately left. State that the site
list comes from a grep for the mechanism's own words, not from memory
of where it is written.

Keep it proportionate: this applies to a `Change` that RELOCATES or
RETIRES a mechanism, not to every edit. A slice that adds a rule
without moving one owes no inventory.
