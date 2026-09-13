One PR on cosmic-lua/cosmopolitan: a check, run as part of
`o//tool/lua/test` (a small Lua or shell test enrolled in
`tool/lua/BUILD.mk` like its siblings), that reads `tool/lua/BUILD.mk`
and asserts every `o//tool/lua/<name>.ok:` rule's recipe ends with
`@touch $@` — fail naming each rule that does not. Alternatively, if the
build already offers a cheaper hook, assert convergence directly: after
the test target completes, every `.ok` named by a rule exists under
`o//tool/lua/`. Pick the one the file's shape makes trivial; the first
reads as a 20-line Lua script.
