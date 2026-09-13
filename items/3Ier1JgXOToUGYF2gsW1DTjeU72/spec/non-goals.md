- **No runtime linkage.** A built artifact never opens another artifact's zip. This
  was considered and dropped: Lua's `package.loaded` is one global table keyed by
  module name, so two versions of a module cannot coexist in one state without a
  private per-package registry, and the memory and C-binding-state cost of that
  buys nothing once the closure is baked in anyway.
- **No content-addressed store.** A Nix-style store is what makes Nix's dedup work,
  and it is an install step, a GC-root problem and a missing-directory failure mode
  on six operating systems. The Nix-shaped half worth having — exact, content-hashed,
  enumerable pins — is already what `*_pin.tl` and D16 do.
- **No registry and no ranges.** Packages are named by url and sha256, as pins are.
- **No solver.**
- **No stdlib shadowing.** A package can never provide `cosmic.*`.
