When a release cut from a main that contains `2724a719` exists (the
release workflow is dispatched by a human or cron — never dispatch one
for this item), bump `bin/cosmic.pin`'s url + sha256 to it, then
`bin/cosmic --make fetch && bin/cosmic --make ci`, fixing whatever the
new pin's types break (expected: nothing — no `cosmo.*` contract
change rides between cb39b65 and the target).
