Restore `VisualizeControlCodes` (as a `cosmo.*` binding, matching
`help.txt:1809`'s documented shape) or remove every demo caller and the
`help.txt` entry, whichever the repo's binding-removal history in
`test_cosmo.lua:89` says was intended — the fix should make
`tool/net/demo/.init.lua`'s `OnHttpRequest` and the four sibling demo
scripts (`redbean.lua`, `redbean-form.lua`, `fetch.lua`,
`unix-finger.lua`) stop referencing a nonexistent global, and keep
`help.txt` in sync with whichever direction is chosen.
