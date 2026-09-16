Every `gitboard worktree` (and so every `handoff`) downloads the pinned cosmic
runtime again into its own `o/.gitboard-runtime-<nonce>/` directory. The
runtime is identified by a pin carrying a sha256, so it is content-addressed
and cacheable, but nothing is shared between worktrees of the same repository
on the same machine.

Cache the verified runtime once per machine, keyed on the pin's sha256, and
link or copy it into each worktree instead of refetching. Verify the sha on
cache read as well as on download, so a corrupted or tampered cache entry is
refused rather than executed.
