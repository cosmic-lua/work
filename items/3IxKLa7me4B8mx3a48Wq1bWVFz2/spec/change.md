1. Trigger `release.yml` via `workflow_dispatch` against `main`
   (current head, which carries #1745) to cut a release — a prerelease
   is fine, `bin/cosmic.pin` already names one. Wait for it to publish
   and confirm its tag's commit descends from #1745's merge commit
   (`git merge-base --is-ancestor <1745-merge-sha> <new-tag-sha>`).
2. Download the release asset, verify its sha256 against the
   published `SHA256SUMS` (or recompute directly), and bump
   `bin/cosmic.pin`'s `url`/`sha256` to the new release.
3. `rm -rf o && bin/cosmic --make fetch && bin/cosmic --make ci` — a
   genuinely cold build/gate on the new pin — must pass, confirming
   generation 1 now type-checks `unix.E`/`unix.SIG` correctly using
   the NEW pinned release's fixed `gentype_parse.tl`.
4. Open a PR for the `bin/cosmic.pin` bump alone. Once it merges,
   PR #1746 (after a rebase/merge of `main`) and board item
   `0Svo_ZeTH` become buildable cold.
