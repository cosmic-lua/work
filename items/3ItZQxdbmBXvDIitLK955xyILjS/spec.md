## Change

Evidence for this container from a break-and-recover experiment
(2026-09-05, ten Sonnet agents upgrading a five-file consumer across
five deliberate `cosmic.*` breaks), and the two measured facts it adds
to the parent's case. Both belong in the strict-mode item's Change
(`3IPXRRd2`) and its test set; this item is done when they are there.

1. Retypings are the dominant public-surface break, and the checker
   sees none of the nil-widening ones. Measured over the tree's own
   history with a surface extractor (every `record` field of every
   public `cosmic/**.tl`, compared between snapshots):

   ```
   $ python3 histdiff.py $(for d in 2026-08-14 2026-08-24 2026-09-01; do git rev-list -n1 --before=$d HEAD; done) HEAD
   ..5f227969 2026-08-24: mod_added=1 fn_added=8 fn_retyped=3 field_removed=3 field_added=5 field_retyped=1
   ..8495ab0a 2026-09-01: mod_added=9 fn_added=13 fn_retyped=9 field_removed=1 field_added=23 field_retyped=3
   ..d3bce229 2026-09-05: mod_added=4 fn_removed=2 fn_added=16 fn_retyped=2 field_removed=4 field_added=12 field_retyped=2
   ```

   Three weeks, 30 breaking changes to public names: 0 modules
   removed, 2 functions removed, 8 record fields removed, and 20
   retypings. Of the 20, seven widen a slot to admit nil or add a
   fallible return where there was none (`rand.choice: any → T | nil`,
   `plan.validate_net: string → string | nil`, `zip.Archive.close:
   () → boolean, string`, `serve_forever: () → boolean, string`,
   `rules.parse_rule`, `SuffixEntry.port`, `ForwardSpec.inject_name`).
   Every one of those is silent for a caller that assigns, concatenates,
   passes, or ignores the result.

2. The silence is total, not partial. Probe against the pinned
   release's checker:

   ```
   $ cat cmd/p/main.tl
   local function f(): string | nil, string
     return nil, "x"
   end
   local a = "a" .. f()
   local b: string = f()
   print(a, b)
   $ cosmic --check types cmd/p/main.tl
   Type check passed: cmd/p/main.tl
   ```

   In the experiment, `string.shell_quote` went from `string` to
   `string | nil, string`. `--make check` on the consumer reported the
   four other breaks and nothing for this one. Under variant D, whose
   only remedy was a hint attached to checker errors, 0 of 2 agents
   narrowed the call; the two designs that found it did so by scanning
   the project's source for the name, not through the checker.

What to carry into `3IPXRRd2`'s Change and tests:

- one test in `cosmic/teal_narrowing_test.tl` shaped like the probe
  above: a function retyped from `T` to `T | nil, string`, used in a
  concatenation and as the initialiser of a `local x: T`, both refused
  by the strict mode with `STRICTNIL` at the two sites. This is the
  upgrade-shaped case: it must fail for a CONSUMER whose source did not
  change while the callee's declaration did.
- the sentence, in the item's prose: strict nil-flow is what makes a
  retyping loud at the call site; until it lands, an honest-nil
  retyping of a public name is a silent break for every downstream
  project, and D10's "honest types make breakage loud" holds only for
  renames, removals, and record-field changes.

## Non-goals

No change to the narrowing patches or the doctrine here; this item
records evidence and names the test. The upgrade tooling the
experiment prototyped (surface diff, usage scan, tombstones) is a
separate design, not this container's.
