**`_perf/bench/literal_bench.tl`** — add one scenario, and nothing
else:

- No new module-level fixture: the scenario formats `FLOOR`, it does
  not read back a prebuilt source, so nothing is added beside
  `PIN_SOURCE`/`FLOOR_SOURCE`.
- Add a fifth entry to the `scenarios()` table, placed immediately
  after `literal_format_floor` (`:121-129`) so it meets the same heap
  as the floor scenario it is compared against:

  ```teal
  {
    name = "literal_format_floor_compact",
    fn = function(_: any): any
      return (literal.format(FLOOR, {layout = "compact"}))
    end,
    check = function(_: any, res: any): boolean, string
      return verify("literal_format_floor_compact", res, FLOOR_ROWS,
        FLOOR_KEY, "covered", FLOOR_COVERED)
    end,
  },
  ```

  `verify` parses a string result back before probing it, so the check
  holds the compact writer to the reader's bar — which is exactly the
  fidelity the parent says a fold must not move.
- Extend the module's header comment to say the file now covers both
  layouts, and why the compact one is here: it is the bulk writer whose
  guard cost the parent hypothesis is about, and a hypothesis with no
  scenario has no gate.
