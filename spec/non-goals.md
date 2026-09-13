- copying the reference APIs' surfaces (builder pattern, `RODirs`
  vs `ROFiles` splits). The declarative `{fs, sys}` table is the
  right door; this epic is entirely beneath it.
- portable default-deny — a goals.md non-goal; unenforcing platforms
  stay honest, never emulated.
- replacing quicksand's netns/proxy. Landlock net is the lighter,
  unprivileged tier beside it, not a successor.
- weakening any existing denial to make a report look better.
