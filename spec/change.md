1. `cosmic/flags/parse.tl:124`: the refusal names the escape. One message shape,
   always, so no heuristic decides when an unknown option "looks like" a positional:

   ```
   unknown option: --docs foo: a title (try --help; an argument that starts with a dash goes after --)
   ```

   `cosmic/flags_test.tl:53`, `:78` and `:199` already assert the `unknown option:
   --nope` prefix with plain `find`, so they keep passing; add one assertion that the
   message contains `after --`.
2. `help()` in `parse.tl`: after the flag rows, one fixed line, rendered for every
   spec:

   ```
       --                 end of options; what follows is positional even if it starts with a dash
   ```

   aligned in the same column the flag rows use (it goes through the same
   `lefts`/`width` pass, so it cannot drift). `flags_test.tl`'s help-rendering test
   asserts the line is present and last.
3. `cosmic/flags/init.tl`'s module doc gains one sentence under the example: `--`
   ends option parsing; everything after it is positional. `parse()`'s own doc
   comment says the same in its `@return` prose for `args`.
4. `sys/help.md`: one line in the "Cosmic options" block, after `--include-dir`,
   in the same column: `  --                            end of options (a script or query
   may then start with a dash)`. `_cli/help_test.tl` compares `_cli/args.tl`'s spec
   against the file; `--` is not a declared flag, so the sync test needs no change —
   verify by running it (`o/bin/cosmic --make test _cli/help_test.tl`) before pushing.
5. The `--docs` handler is unchanged: `cosmic --docs -- "--recipe"` already reaches it
   with the query intact (the parser strips the terminator); the test in
   `_cli/main_handlers_test.tl` adds that case so the path stays covered.
