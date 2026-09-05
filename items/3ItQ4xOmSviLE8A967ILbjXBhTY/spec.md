## Evidence

A positional argument that begins with a dash is refused by every `cosmic.flags`
program as an unknown option, and nothing the program prints says how to pass one.
Shell quoting cannot help — quotes never reach the program — and the escape that
exists, the POSIX `--` terminator, is honored by the parser but undocumented and
unmentioned by the refusal.

Reproduced 2026-09-05 with the pinned gitboard (a `cosmic.flags` program) against a
throwaway board (`gitboard init` into a temp directory):

```
$ gitboard new "--docs foo: a title"; echo "exit=$?"
unknown option: --docs foo: a title (try --help)
usage: gitboard <command> [options]
...
exit=1
$ gitboard new -- "--docs foo: a title"
gitboard-new: 3ItPrEBpLmQjjyrVnqAvdDFKGJE enters triage — attach it under something, or compare it
$ gitboard new "-c foo"
unknown option: -c (try --help)
```

So `--` works: `cosmo.getopt` stops option parsing at it, and the shard's test pins
that (`cosmic/flags/getopt_test.tl:81`, `getopt.parse({"-v", "--", "-h", "file.txt"},
"vh")`). But at the public surface:

- the refusal is built at `cosmic/flags/parse.tl:124` —
  `"unknown option: " .. r.unknown[1] .. " (try --help)"` — and `--help` does not
  answer, because
- `help()` (`parse.tl:201`) renders one row per declared flag and nothing about `--`;
- `--docs cosmic.flags` never mentions it (`o/bin/cosmic --docs cosmic.flags | grep
  -c -- '--'` finds only the flag rows in its example);
- `sys/help.md`, cosmic's own `--help`, has no line for it either, and cosmic's flag
  set includes `--docs QUERY` with an optional argument, so `cosmic --docs
  "--recipe"` is refused the same way.

Three titles filed to the board on 2026-09-05 hit this: each began with `--docs` or
`--check` (the name of the surface the item was about) and was refused with the whole
title echoed back as the unknown option. The fix was reading the parser's source; a
user of a cosmic-built binary has only the message.

## Change

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

## Non-goals

Accepting a dash-led positional WITHOUT `--` by guessing (an argument with a space or
a colon in it is "obviously" a positional) — a heuristic refusal is worse than a
documented escape, and `--` is the convention every shell user already knows.
gitboard's own `new` usage text, which is the work repository's (filed beside this
item). Short-option clustering or any other parser behaviour.
