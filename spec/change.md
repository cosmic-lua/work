`_make/policy.tl` (or the coverage stage that renders the ratchet):
after a passing or failing `--make coverage`, for every measured file
with no row in `.cosmic-coverage`, print one line in the file's own
row syntax, e.g. `  ["_make/seed.tl"] = {covered = 40, total = 49},`,
under a header "new files, rows to add by hand". The refusal text at
:178-184 then says "a new file's row is printed by a plain `--make
coverage`; paste it" and drops the sentence that names the env var
(the recording lane sets it for itself and needs no prompt).

`_make/policy_test.tl`: a fixture with one unlisted file asserts the
printed row; the refusal text assertion updates.
