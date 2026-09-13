- **Do not touch `3p/tl/tl_patch/**`.** No entry added, removed,
  renamed, or edited. Two open PRs are changing that directory; this
  slice reads it and nothing more.
- **Do not touch `cosmic/searcher.tl`.** Its precedence is deliberate —
  an artifact running as itself resolves its own embedded modules
  first — and `wc -l cosmic/searcher.tl` is 498 against the 500-line
  cap, so there is no room for a note there. In particular, do not add
  a warning when `package.path` shadows an embedded module: that is a
  runtime behaviour change to every artifact, not this slice.
- **Do not change the existing `_make.patch` surface.**
  `paths_of_pin`, `read`, `read_all`, `applied` and `apply` keep their
  signatures and their message text. `grep -n 'patch\.[a-z_]*(' _make/fetch.tl`
  returns 5 lines today — `paths_of_pin` twice, `read_all`, `apply`,
  `applied` — and `read` is reached through `read_all`.
- **Do not edit `AGENTS.md`.** Line 176 already names `_make/patch.tl`
  as the patch mechanism, which is the pointer; the sentence around it
  is about nil-union narrowing and a probing clause does not belong in
  it.
- No new `--make` verb, no CLI flag, and no `_cli/build/` change:
  `reverse` is a module function a probe script requires.
- `reverse` does not restore `package.loaded` and does not delete its
  temporary copy. It is a probe.
- No change to `cosmic/teal.tl` or `cosmic/_teal_engine.tl`.
- Do not weaken the coverage ratchet. `.cosmic-coverage` line 75 reads
  `["_make/patch.tl"] = {["covered"] = 81, ["total"] = 87}` today; if
  `--make coverage` refuses the new floor, run exactly
  `bin/cosmic --make coverage --baseline` and commit the rewritten
  `.cosmic-coverage`. Any other way of quieting it is out of scope.
