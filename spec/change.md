1. `cosmic/doc/query.tl`: in `run()`, add an `examples.<name>` dispatch
   immediately after the existing `query == "examples"` branch (line 376-379),
   delegating to the already-exported `module_examples`:
   ```
   if query:sub(1, 9) == "examples." then
     return module_examples(query:sub(10))
   end
   ```
   This makes `cosmic --docs examples.child` behave exactly like
   `cosmic --examples child` does today — same underlying call,
   `module_examples`, unchanged.
2. `_cli/main_handlers.tl`: rewrite `handle_examples` (currently
   lines 297-310) to route both its branches through `docs.query`, so there is
   one call site behind both flags instead of two:
   ```lua
   local function handle_examples(module_name: string): integer
     local docs = require("cosmic.doc")
     local query = module_name == "" and "examples" or ("examples." .. module_name)
     local out, qerr = docs.query(query)
     io.write((out or qerr) .. "\n")
     return out and 0 or 1
   end
   ```
   `--examples` and `--docs` remain two flags at the CLI surface (no breaking
   removal — see Non-goals), but they are no longer two *implementations*:
   `--examples <m>` is now defined as sugar for `--docs examples.<m>`.
3. `sys/help.md`: add a line documenting the new `--docs examples[.<module>]`
   form next to the existing `--docs [query]` entry (line 39), so the
   consolidated path is discoverable without needing `--examples` at all —
   e.g. `--docs examples[.<module>]     same as --examples [module]`.
4. Tests: extend `cosmic/doc/query_test.tl` (or add alongside
   `cosmic/doc/examples_query_test.tl`, which already tests
   `module_examples` directly) with a case asserting
   `docs.query("examples." .. mod_name)` and `docs.module_examples(mod_name)`
   return the same string for some module with examples in the embedded
   index — pinning the equivalence this change relies on. Extend
   `_cli/main_handlers_test.tl` with a case that `--examples <mod>` and
   `--docs examples.<mod>` produce identical stdout for the same module (the
   existing test file already drives `--make`/CLI dispatch end-to-end per
   `test_make_dispatches_verb_and_paths`, `_cli/main_handlers_test.tl:161-`,
   as a pattern to follow).
