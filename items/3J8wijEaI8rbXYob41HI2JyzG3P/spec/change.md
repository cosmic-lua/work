Add one test-only `_cli` helper that runs the tree's `bin/cosmic` launcher in a
fresh child process and checks a table-shaped case containing:

- argument vector and optional working directory;
- exact exit code, stdout, and stderr; and
- an optional list of paths that must not be created.

Add or migrate a small representative harness test covering:

1. an option missing its required value, proving parser -> dispatcher behavior;
2. one successful exact-output command; and
3. a fixed-precedence command whose losing action would create a forbidden
   path.

Use existing process/temp-directory primitives and the repository's spawned
binary test conventions.  The helper must report the invoked arguments and the
first differing stream/exit/side-effect in a failed assertion.  Keep the slice
test-only, at most three files and 180 changed lines.  Bounce if production CLI
behavior must change or if a general subprocess framework is required.

Run the new test file, its mutation, format/types for changed Teal, and the
existing spawned-binary dependency guard.  Mutation: change one expected exit
or stream and show the corresponding case fails, then restore it.
