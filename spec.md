## Change

Ready when: the gone tree exists on main (`ls cosmic/_gone/`; sibling
item `7SGj_Mojk`).

When the checker refuses a call to a name that left, the error itself
says where it went. Two hint sites already exist and both are
message-shaped, so the change is one gone-tree index and two lookups.

**Index.** `cosmic/_gone/index.tl` — wait: nothing under `_gone/` may
be a module anything requires; put it in `_tool/gone.tl` (new, ~80
lines, embedded through the import closure like `_tool/surface.tl`).
`index(): {string: Entry} | nil, string` lexes every
`/zip/.tl/cosmic/_gone/**.tl` once per process, lazily, and returns
entries keyed two ways so a hint can be answered from what a message
carries: by `"<Record>.<field>"` (the checker names the record type,
never the module) and by module name for a whole module that left.
`Entry` is `{module: string, field: string, since: string, sentence:
string, has_wrapper: boolean}`. A missing `_gone` tree (an older
binary, a stripped artifact) yields an empty index, never an error.

**Site 1 — invalid key.** `cosmic/_teal_hints.tl` (138 lines),
`hint_for_message(msg)` at line 24; the record-key branch at line 87
returns the generic "the value's record type does not declare this
key" hint. Before it, match
`invalid key '(%w+)' in record '%w+' of type record (%w+)` and look up
`"<Record>.<key>"`; on a hit return

```
  hint: cosmic.string.truncate left this release (gone 2026-09-06): renamed; same arguments, same result — `cosmic --upgrade` lists every such use, `cosmic --upgrade apply` rewrites it
```

(no `apply` clause when `has_wrapper` is false). The generic hint
stays for every miss. The record name is what the checker prints, and
the gone key carries the record because `_tool/surface`'s key grammar
does; no record-to-module table is kept anywhere.

**Site 2 — module not found.** `_cli/require_hints.tl` (260 lines),
`format_error(name)` at line 141 builds the runtime "module not found"
message with `find_similar` suggestions; the compile-time message
comes from tl and passes through `hint_for_message` too. In both
places, a `cosmic.<m>` name with a gone file (`index()[name]`) says
`cosmic.uuid left this release (gone 2026-09-06): the module folded
into cosmic.rand — see cosmic --upgrade`, ahead of the did-you-mean
list.

**What this does not catch, by construction.** `unknown field pretty`
names neither record nor module, and a retyped name produces no error
at all (probe in `55xyILjS`); both are the `--upgrade` report's job,
and the hint text points there so a reader who hits one error learns
the verb that finds the rest.

Measured shapes the hints must match, from the pinned release on the
experiment's consumer:

```
notes/render.tl:10:53: error: invalid key 'truncate' in record 'str' of type record StringModule
notes/store.tl:6:21: error: module not found: 'cosmic.uuid'
notes/store.tl:45:46: error: unknown field pretty
```

Tests: `_tool/gone_test.tl` over a fixture `_gone` tree in
`TEST_TMPDIR` (index() takes an optional root for tests): both key
forms, the `since` and sentence extraction from the `--- gone` doc
line and the `-- gone` line, and the empty-index path.
`cosmic/teal_test.tl` (or a new `cosmic/teal_hints_test.tl` if the
former is near the cap — measure) asserts the two hint strings for
the two messages above against a fixture index, and that the generic
hint still returns for an unknown key.

## Non-goals

No change to what the checker accepts; hints only. No `--docs` page
for gone names (a possible follow-up: `--docs cosmic.string.truncate`
serving the wrapper's doc line).
