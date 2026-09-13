1. **Wait for or trigger the release.** If no release tagged
   2026-08-27 or later exists, dispatch release.yml (cron default,
   prerelease) or wait for the 06:00 UTC cron. Verify eligibility:
   the tag's sha has `1ca3f7ff` as an ancestor. If the release lane
   turns out red, that repair is its own item — file it and block
   this one on it rather than debugging inside this slice.
2. **Bump `bin/cosmic.pin`**: new `url` (the tag's `cosmic-lua`
   asset) and `sha256` (compute from the downloaded asset; never copy
   from a third party). Only those two lines change.
3. **Cold-start proof**: `rm -f o/bin/cosmic && bin/cosmic --make
   fetch && bin/cosmic --make ci` — the trust root re-fetches the new
   pin, verifies the sha, and the whole gate converges under it.
4. **Checker proof**: write the probe to scratch —
   `local t = table.pack(1, "a")` then
   `local s: string = t.n` — and run the PINNED binary's
   `--check types` on it BEFORE the tree build overwrites
   `o/bin/cosmic`: the run must FAIL naming the integer/string
   mismatch. Record the command and output in the PR body.
5. **PR** with the pin diff only; on land, `gitboard unblock`/land
   flow clears 3ISPGV8z's blocker.
