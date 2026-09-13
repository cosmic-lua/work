No transform for record-field changes, options values, or names with
no replacement: those stay report-only by design. No multi-hop across
releases: a project two releases behind runs apply once against the
binary it has, which carries every wrapper still in the tree. No
general scope-aware binding resolution (shadowing, re-assignment,
loop-bound aliases) — the require-alias dependency is intentionally
narrower than the `«HlZW_zWbs»` investigation's scope; a file that
rebinds an alias mid-function is out of scope and apply skips uses
past the rebinding (report continues to list them).
