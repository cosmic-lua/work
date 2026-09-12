## Goal

Carries forward cosmic-lua/cosmic#818: `--examples` and `--docs` are "one thing
wearing two names" at the CLI surface. Confirmed still true and still
unconsolidated in the current tree. Rather than leave the "what surface should
this be" question open again (the issue's own stated blocker: "needs a decision
on the surface... before it is actionable"), this spec makes that call and
gives it a concrete, low-risk, non-breaking edit: fold `--examples`'s "one
module's examples" lookup into the *same query path* `--docs` already uses for
the "list all examples" case, so there is exactly one implementation behind
both flags instead of two. Serves G4 (zero-config project gates: a coherent,
learnable CLI surface) and closes the specific duplication the issue evidences,
without a breaking removal this session cannot fully evaluate (see Non-goals).

## Evidence

Confirmed both flags are still fully separate today, in `cosmic-lua/cosmic`
`main` (`c9cdb84211b00239dfc88d3331fe2785d33800a0`, fetched 2026-09-12):

```
$ grep -n "long = \"examples\"\|long = \"docs\"" _cli/args.tl
50:    {long = "examples", arg = "MODULE", arg_optional = true,
53:    {long = "docs", arg = "QUERY", arg_optional = true, help = "query docs"},
```

Two separate handlers in `_cli/main_handlers.tl`:

```
297  --- Handle --examples flag.
298  local function handle_examples(module_name: string): integer
299    local docs = require("cosmic.doc")
300
301    if module_name == "" then
302      local out, qerr = docs.query("examples")
303      io.write((out or qerr) .. "\n")
304      return out and 0 or 1
305    else
306      local out, qerr = docs.module_examples(module_name)
307      io.write((out or qerr) .. "\n")
308      return out and 0 or 1
309    end
310  end
...
332  --- Handle --docs flag: exact lookup first, then search fallback.
333  local function handle_docs(query: string): integer
334    local docs_mod = require("cosmic.doc")
335    local out, qerr = docs_mod.query(query)
```

The "list all examples" branch (`module_name == ""`) already calls
`docs.query("examples")` — the identical call `cosmic --docs examples` makes
via `handle_docs` → `docs.query` → `cosmic/doc/query.tl`'s `run()`:

```
$ grep -n 'query == "examples"' cosmic/doc/query.tl
376    if query == "examples" then
```

So `cosmic --examples` and `cosmic --docs examples` are, right now, two
dispatcher paths converging on the exact same function call for that case —
the literal duplication #818 complains about, reproduced.

The remaining branch — `--examples <module>` — is NOT reachable through
`--docs` at all: it calls `docs.module_examples(module_name)` directly, and
`cosmic/doc/query.tl`'s `run()` has no dispatch for it:

```
$ grep -n "examples\." cosmic/doc/query.tl
310:    -- function-filter interpretation before reporting no examples.
```

(the only hit is an unrelated comment inside `module_examples`'s own body —
no `examples.<name>` query prefix exists). `module_examples` itself already
accepts a bare or dotted module name and resolves it
(`cosmic/doc/query.tl:289-`):

```
289  local function module_examples(query: string): string | nil, string
...
295    local resolved = idx.modules[query] and query or
        (idx.modules["cosmic." .. query] and "cosmic." .. query or nil)
```

and is already exported on the `cosmic.doc` record (`cosmic/doc/init.tl:48,66`:
`module_examples: function(query: string): string | nil, string` /
`module_examples = query.module_examples`), so `handle_docs` could reach it
today if `query.run` dispatched to it — nothing about `module_examples` itself
needs to change.

`sys/help.md` documents them as two adjacent, separately-described flags
(unchanged today):

```
$ grep -n '\-\-examples\|\-\-docs' sys/help.md
33:  --examples [module]           browse examples (list all, or show module)
39:  --docs [query]                show documentation for module, symbol, or guide
```

## Change

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

## Non-goals

- **Removing `--examples` as a top-level flag.** The issue itself frames
  "whether the consolidated form is a breaking CLI change" as an open
  question needing its own decision; this slice answers it conservatively
  (no removal, no deprecation warning) so it ships as a pure internal
  de-duplication. Dropping `--examples` entirely — or aliasing it with a
  deprecation notice — is a separate, riskier follow-up that needs its own
  call (arguably a `docs/decisions/` entry, since D26 gates directional CLI
  surface changes) and is explicitly out of scope here.
- **`cosmic --make docs` / `_docs/`** (doc *publishing*, a different system
  with a similar name) is unaffected and untouched — the issue names the
  adjacency only to rule out confusing the two; this slice does not touch
  `_docs/`.
- **`--check-examples`** (`_cli/args.tl:108`, a distinct `--check` sub-verb
  that type-checks example files, unrelated to browsing them) is untouched.
- Command-parsing changes sit inside this project's pre-install boundary
  (`AGENTS.md`, "Build System"); this slice adds a new query *string* dispatch
  inside `cosmic.doc`, not a new flag or a changed flag arity, so it is not
  expected to need the release/pin staging that boundary's signature changes
  require — call this out explicitly in review if that reading is wrong.

## Access

None beyond `cosmic-lua/cosmic` itself — no other repository is read or
written by this change.
