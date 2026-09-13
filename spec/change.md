`bin/gitboard.pin`: set `url` to that release's `gitboard` asset and
`sha256` to the asset's actual digest (`curl -sL <url> | sha256sum`),
both fields in one commit, comment header unchanged. Then, from this
checkout, `bin/gitboard sync` must end `gitboard-sync: state is
current` and `bin/gitboard show --todo 0 | head -3` must print todo
rows (the #48 flag; if #48 has not merged, `bin/gitboard help show`
must at least run under the new pin) — the run is for the builder,
never pasted into the PR body (`gitboard help build`: the body carries
no evidence — CI is the proof). `bin/cosmic --make ci` ends `ci: PASS`
(the pin file is data; the gate proves nothing else broke).
