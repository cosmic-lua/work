Not changing gitboard's own behavior. The reason `refresh --execute` cannot
perform the one-time fetch is a defect in cosmic-lua/work, filed separately;
this item stays a docs-only fix so a new session stops hitting a dead command
today. When that defect lands, the `git fetch` stanza here collapses to
nothing and a follow-up removes it.

This item does not claim `sync`/`refresh` are working as designed — an earlier
revision of this spec asserted that from the help text, and the probe above
disproves it.
