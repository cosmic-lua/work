**1. `cosmic/_literal_format.tl` — a strict pre-walk and a compact writer.**
Add two internal functions and export the second:

- a walk that visits every key and value of the value once, capped by the
  module's own `MAX_DEPTH` (`cosmic/_literal_format.tl:18`, already 32 and
  already deliberately duplicated from `cosmic/literal.tl:48` so the writer
  refuses exactly the depth the reader refuses), and returns `nil, msg` on the first
  offender, where `msg` is built by the module's existing `refusal(path, what)`
  so the message wording and key paths match what `format` already produces for
  the same input. It refuses: a non-string key, a number that is NaN or
  infinite, any value that is not string/number/boolean/table, and a table
  reached twice on the current path (a cycle).
- `format_compact(value: any): string | nil, string` — runs that walk, and on
  success returns `"return " .. cosmo.EncodeLua(value, {sorted = true}) .. "\n"`.

**2. `cosmic/literal.tl` — an options argument on `format`.** Widen the export
to `format(value: any, opts?: FormatOptions): string | nil, string`, with
`record FormatOptions layout: string end` taking `"pin"` (the default, dispatching
to today's `lformat.format`, unchanged) or `"compact"` (dispatching to
`format_compact`). Any other value is refused with a message naming the two
accepted ones. Declare the record and the widened signature on `LiteralModule`,
and document on `format` that `"pin"` is a fmt fixpoint suitable for a committed
file while `"compact"` is the bulk path: same domain, same refusals, smaller and
faster output, no fixpoint promise.

**3. Tests.** `cosmic/literal_test.tl` has 79 lines of headroom, which is tight;
put the new tests in a new `cosmic/_literal_format_test.tl` instead, following
the house pattern (each `test_*` called on the line after its `end`). Cover: the
default and explicit `"pin"` layouts are byte-identical to today's output for a
nested payload; `parse(format(v, {layout = "compact"}))` deep-equals `v`; each
of the eight rows in the refusal table above is refused under `"compact"` with
the same key path `"pin"` refuses it with; and an unknown `layout` value is
refused.
