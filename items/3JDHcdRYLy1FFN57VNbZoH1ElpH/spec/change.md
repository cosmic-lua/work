Add `tool/lua/test_ljson_ascii.lua` to freeze the current decoder's string
behavior and add a deterministic differential corpus driver under
`tool/lua/testdata/json_ascii_corpus.lua`. Wire the new test into
`tool/lua/BUILD.mk` using the existing test_ljson test recipe and aggregate
test dependencies. This is a test-only PR; leave ljson.c unchanged.
