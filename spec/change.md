`tool/lua/test_definitions_coverage.lua`, check 9's `parse_union`:
mirror the downstream rule exactly — at bracket depth 0 of the type
region (outside any `()`, `{}`, `<>`), a `|` must be followed
immediately by a type character; whitespace, end of string, or an
identifier that then reads as the slot name after a depth-0 bar is a
malformed annotation the check reports by binding name, the same way
its other malformations are reported. Inside a bracketed group,
whitespace around `|` stays legal, so the two `unix.ioctl` lines above
keep passing and the gate is green on the unmodified head.

The file has no self-check fixtures for any check today (every check
scans `definitions.lua` only), so add one for this check: inside check
9's `do` block, a small table of known-good and known-bad type strings
run through the same parser entry (`type_ok` or whatever the check
calls), asserting each classification — at least `integer| cols`
(bad), `integer|` (bad), `integer|string` (good), `(integer | string)?`
(good), `(true|nil | string)` (good). That table is the red-before /
green-after demonstration the reviewer holds the diff against.
