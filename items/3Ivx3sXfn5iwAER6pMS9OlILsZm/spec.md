## Evidence

Teal's lexer hands `<const>`/`<close>` back as three ordinary tokens
with no distinct attribute kind — confirmed directly:

    $ cat > lex.lua <<'LUA'
    local tl = require("tl")
    for _, t in ipairs(tl.lex("local x <const> = 1\n")) do
      print(t.y, t.x, t.kind, ("%q"):format(t.tk))
    end
    LUA
    $ bin/cosmic lex.lua
    1  1   keyword     "local"
    1  7   identifier  "x"
    1  9   op          "<"
    1  10  identifier  "const"
    1  15  op          ">"
    ...

`needs_space` (`cosmic/format/rules.tl:167-232`) has no case for this
shape, so it falls through to ordinary comparison-operator spacing:

    $ printf 'local x <const> = 1\nlocal y <close> = 1\nprint(x, y)\n' > t.tl
    $ bin/cosmic --format t.tl
    local x < const > = 1
    local y < close > = 1
    print(x, y)

Standard Lua/Teal style writes these tight: `<const>`, `<close>`. This
is not hypothetical or rare — it's already landed on the committed
tree:

    $ grep -rn "< const >\|< close >" --include="*.tl" . | grep -v "^./o/" | wc -l
    355

The same root cause (an untreated `<...>` window) also mis-spaces
GENERIC type parameters on `record`/`interface` declarations, which is
inconsistent with generic FUNCTIONS, which already render tight:

    $ cat g.tl
    local record Box<T>
      value: T
    end
    local function f<T>(x: T): T
      return x
    end
    $ bin/cosmic --format g.tl
    local record Box < T >
      value: T
    end
    local function f<T>(x: T): T
      return x
    end

`mark_type_params` (`cosmic/format/init.tl:36-64`) is the existing
mechanism that makes `function<T>(` render tight; it only checks
`item.tk == "function"` (line 38), never `record`/`interface`
(`type_decl_kw`, `cosmic/format/rules.tl:99-103`), so their generics
take the untreated path instead.

## Change

Generalize the tight-angle-bracket mechanism so one pass covers all
three shapes instead of `mark_type_params` special-casing only
`function`:

- Extend the trigger in `mark_type_params` (`cosmic/format/init.tl:36-64`)
  to also fire when `item.kind == "identifier" and type_decl_kw[item.tk]`
  (i.e. `record`/`interface`) followed by a NAME then `<` — reuse
  `type_decl_kw` from `cosmic/format/rules.tl:99-103` (export it if it
  isn't already visible from `init.tl`).
- Add a second trigger for the attribute shape: an identifier
  immediately preceded by `local`/`global` (or by a `,` inside a
  multi-name local/global list) followed by `<`, `const` or `close`,
  `>` — mark all four tokens `_tight_before` the same way generics are
  marked today.
- Both go through the SAME `_tight_before` field `needs_space` already
  respects (`cosmic/format/init.tl:289`), so no change to
  `needs_space` itself is needed for this item.

Because `--check fmt` is an exact-text match, this rule change makes
every one of the 355 currently-committed `< const >`/`< close >`
occurrences fail the gate the moment it lands — this item's diff MUST
include a tree-wide `--fix` sweep in the same PR/commit (a mechanical,
review-as-such diff; the sizing guideline's "~400 changed lines" smell
does not apply to a whitespace-only mechanical reformat, same as any
other formatter-rule change). Re-run the 355-count grep above after
the sweep and confirm it returns 0.

## Acceptance

`cosmic/format/regressions_test.tl`: `local x <const> = 1` and
`local y <close> = 1` format unchanged (tight); `local record
Box<T>` and `local interface Comparable<T>` format tight; and a
negative case — plain `x < y` and `x > y` comparisons, and a bare
`local x < 1` (nonsense but must not be treated as an attrib) — still
get spaced, to guard against over-tightening. Then the tree-wide sweep
described above, verified by `bin/cosmic --make ci` passing `fmt`
clean.
