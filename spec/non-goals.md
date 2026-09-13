Moving `_cli/lint`'s per-file rules onto the db — `--check lint <file>` runs on ONE
file with no build, and a lexer pass per file is its correct cost. Replacing the
committed baselines. Any change to `o/project.mk` or the `embed/cosmic.mk` rules.
Shipping the db in the artifact.
