Three files.

1. **`3p/cosmos/cosmos_pin.tl`** — `version` to
   `"2026.08.26-fe7c36c4c"` and the `["*"]` `sha` to
   `"1b54fceb616831aa155da03b5f26865a1d180f02908a82e56dd022fcd87c5d17"`.
   Nothing else in the file moves. Then `bin/cosmic --make fetch`.

2. **`cosmic/_literal_format.tl`** — delete the walk, ask the encoder.

   Rewrite `format_compact`'s body (currently `:395-411`) to:

   ```text
   local function format_compact(value: any): string | nil, string
     if value is {any: any} then
       local encoded = cosmo.EncodeLua(value,
         {sorted = true, literal = true, maxdepth = MAX_DEPTH})
       if not encoded then
         return format(value)
       end
       return "return " .. encoded .. "\n"
     end
     return nil, "a " .. type(value) .. " is not a literal table"
   end
   ```

   Take only the FIRST return. The refusal reason is deliberately
   discarded: the handoff to `format(value)` is what produces the
   message, and `test_compact_refuses_what_pin_refuses` pins that the
   two layouts give the same one. Binding the second return would be an
   unused local, which `--check types` fails.

   Then delete, by line range at `7e8e1170` (top-down, so the earlier
   ranges stay valid):

   - `:316-363` — `is_compact_writable` and its doc comment.
   - `:301-315` — `RESERVED` and its doc comment.
   - `:65-93` — `is_compact_scalar` and its doc comment.
   - `:50-64` — `is_compact_string` and its doc comment.

   Keep `is_finite` (`:39-48`) and everything else.

   Rewrite `format_compact`'s doc comment (`:364-394`). Two paragraphs
   in it describe the deleted walk and must go or change: *"The check is
   not optional. `cosmo.EncodeLua` never refuses…"* — it does now, and
   that is the point — and *"Whatever the walk turns down goes to the
   renderer…"*, which must name the encoder's refusal instead. Keep the
   paragraph on `sorted` and the paragraph explaining why the handoff
   covers both reasons; state that `maxdepth` is pinned to `MAX_DEPTH`
   for the reason in Evidence. Follow the `docs-style` skill: describe
   what the code is for, not what it used to be — no reference to the
   walk having existed.

3. **`cosmic/_literal_format_test.tl`** — pin the depth boundary, which
   nothing pins today. Add one test beside
   `test_compact_falls_back_to_pin_when_it_cannot_spell`, calling itself
   on the line after its `end` per AGENTS.md:

   - a value nested exactly 32 tables deep with a scalar in the
     innermost table round-trips through `written(v, {layout =
     "compact"})` and `literal.parse`, and equals `written(v)` — it now
     takes the pin-layout handoff;
   - a value nested 31 deep with a scalar leaf does NOT fall back
     (`compact ~= written(v)`, and the compact output is one line);
   - a value nested 33 deep is refused, with `refused(v, {layout =
     "compact"}) == refused(v)`.

   Build the nesting with a loop, not 32 literal braces.

   Also fix the file's header comment (`:2-9`), which opens *"The
   compact layout hands the value to a C encoder that never refuses"* —
   no longer true, and it is the sentence that explains why the rest of
   the file exists. Say instead that the encoder is asked to refuse the
   reader's domain itself, and that these tests state the property that
   makes the layout usable: it admits exactly the values the default
   layout admits, hands the rest to that layout, and what it writes is
   what `parse` reads back.

`_types` regenerates from the new `definitions.lua` as a consequence of
the build — no regen step, per AGENTS.md.
