Two files. No new module.

### 1. `_make/patch.tl` — add `patch.reverse`, the inverse of `patch.apply`

Measured 2026-08-27: `wc -l _make/patch.tl` is 255 (245 lines under the
500-line cap); `grep -c 'package.loaded' _make/patch.tl` is 0.

Add one options record and one exported function, beside the existing
`apply`:

```teal
--- Which entries to reverse, in which unpacked file, loaded as what.
local record Options
  --- The pin's source path, e.g. "3p/tl/tl_pin.tl".
  pin: string
  --- The pin's unpack directory, e.g. "o/3p/tl".
  dir: string
  --- Entry names to reverse. Must be non-empty.
  entries: {string}
  --- The file under `dir` to load, e.g. "tl.lua". Every named entry
  --- must target it.
  file: string
  --- Module name to install the loaded copy as, e.g. "tl".
  module_name: string
end

--- @return any|nil The loaded module
--- @return string The error
reverse: function(opts: Options): any, string
```

Export both through `PatchModule` (`type Options = Options` and the
`reverse` field), as `Edit` and `apply` already are.

Behaviour, in this order. Every failure returns `nil` plus one string
prefixed `make: `, in the style of the existing messages:

1. `paths_of_pin(opts.pin)` then `read_all` — propagate their errors
   unchanged. A pin carrying no patch is an error here, not a nil-nil
   miss: `"make: " .. opts.pin .. ": carries no patch to reverse"`.
2. Refuse an empty `opts.entries`:
   `"make: reverse needs at least one entry name"`.
3. Refuse a name in `opts.entries` the set does not declare, naming it
   and the pin.
4. Refuse a named entry whose `file` field is not `opts.file`, naming
   the entry, its file, and `opts.file`.
5. Read `fs.join(opts.dir, opts.file)`. For each name in
   `opts.entries` order, count occurrences of that entry's `replace`
   with the existing local `count`; unless it is exactly 1, refuse with
   a message naming the entry, the count, and that the unpack directory
   is not patched — run `--make fetch`. Otherwise rewrite with
   `str.replace(text, e.replace, e.find, 1)`.
6. Write the rewritten text into a fresh `fs.temp_dir` (under
   `TEST_TMPDIR` when set, else `/tmp`), named after `opts.file`'s
   basename. Never write into `opts.dir`.
7. `package.loaded[opts.module_name] = dofile(<that path>)`, then
   return that value. Installing before returning is the point: a
   caller handed the module and left to install it can install it
   wrong.

Give `reverse` a doc comment stating that it installs into
`package.loaded` because `require` reads that table before any
searcher, and that a caller whose process outlives the probe saves and
restores `package.loaded[opts.module_name]` itself — `reverse` does not
restore.

Then add a `Probing an entry` paragraph to the module's header doc
comment, immediately after the bullet list that ends `unpack directory
under `o/``, before the `return { … }` example. It states, as fact
about the code as it is today:

- A modified copy of a pinned file placed on `package.path` is ignored.
  `require` resolves a module the binary embeds from its own `/zip`
  before `package.path` is consulted, so such a probe measures the
  shipped copy and reports a confident wrong answer with nothing
  logged.
- `patch.reverse` is the probe: it reverses named entries into a
  temporary copy and installs it in `package.loaded`, which `require`
  reads before any searcher.

Write it to the house docs standard: state the fact as it is today, no
history, no board or issue references, no narration of who got this
wrong.

### 2. `_make/patch_test.tl` — four tests

Measured 2026-08-27: `wc -l _make/patch_test.tl` is 155;
`bin/cosmic --make test _make/patch_test.tl` ends `6 tests: 6 passed`
and `test: PASS (1 file)`.

Re-measured at pull: the test runner discovers `test_*` functions by
name. `bin/cosmic --make test _make/patch_test.tl` reports `6 test
functions` and the file carries no call lines, so new tests add none
either.

- `test_package_path_does_not_override_an_embedded_module` — pins the
  trap. With `NAME = "cosmic.string"`: write
  `<tmp>/cosmic/string.lua` returning `{SCRATCH_MARKER = "shadow"}`;
  save `package.loaded[NAME]` and `package.path`; prepend
  `<tmp>/?.lua`; assert `package.searchpath(NAME, package.path)` is the
  shadow file, so the path genuinely names it first; set
  `package.loaded[NAME] = nil`; `require(NAME)`; restore
  `package.loaded[NAME]` and `package.path` BEFORE asserting; assert
  the result's `SCRATCH_MARKER` is nil.
- `test_reverse_loads_the_reversed_copy` — synthetic fixture, no real
  pin. In a temp dir write `x_pin.tl` (`return {}`), `x_patch.tl` with
  one entry whose `file` is `m.lua`, `find` is `return {v = "stock"}`
  and `replace` is `return {v = "patched"}`, and `m.lua` holding the
  `find` text. `patch.apply` it, then `patch.reverse` with
  `module_name = "_make_patch_probe_fixture"`. Assert the returned
  table's `v` is `"stock"`, that `package.loaded[...]` is that same
  table, and that `m.lua` in the temp dir still holds the patched text
  — reverse copies, it does not edit in place. Clear
  `package.loaded[...]` at the end.
- `test_reverse_refuses_unknown_and_mismatched_entries` — on the same
  fixture, assert `reverse` returns nil plus a message for: an empty
  `entries`, a name the patch does not declare, and a name whose entry
  targets a different `file` than `opts.file`.
- `test_reverse_flips_the_checker_on_the_real_pin` — the end-to-end
  proof, against `3p/tl/tl_pin.tl` and `o/3p/tl/tl.lua`, reversing the
  single entry `narrow-truthiness`. The snippet, as a long string:

  ```
  local record R
    x: integer
  end
  local function f(r: R | nil): integer
    if not r then
      return 0
    end
    return r.x
  end
  return f
  ```

  With `cosmic.teal` as loaded, `teal.check(src, {chunk_name =
  "snippet.tl"})` reports 0 errors. Then save `package.loaded["tl"]`,
  call `patch.reverse{pin = "3p/tl/tl_pin.tl", dir = "o/3p/tl",
  entries = {"narrow-truthiness"}, file = "tl.lua", module_name =
  "tl"}`, re-check the same snippet, restore `package.loaded["tl"]`
  immediately, and only then assert: the reversed run reported at least
  one error and one of the messages contains `cannot index key`.
  Restoring before asserting is what keeps a failure from leaving a
  de-patched checker installed for the rest of the process. Verified
  by hand 2026-08-27 with the same reversal driven by a scratch
  script: shipped `0` errors, reversed `1` error, `cannot index key
  'x' in variable 'r' of type R | nil`.
