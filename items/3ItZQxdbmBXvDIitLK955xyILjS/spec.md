## Change

Evidence for this container from a break-and-recover experiment
(2026-09-05, ten Sonnet agents upgrading a five-file consumer across
five deliberate `cosmic.*` breaks), and the two measured facts it adds
to the parent's case. Both belong in the strict-mode item's Change
(`3IPXRRd2`) and its test set; this item is done when they are there.

1. Retypings are the dominant public-surface break, and the checker
   sees none of the nil-widening ones. Measured over the tree's own
   history with a surface extractor (every `record` field of every
   public `cosmic/**.tl`, compared between snapshots), against these
   exact commits — pinned by full sha, not a `--before=DATE` recipe,
   which a fresh-context review found timezone-sensitive and
   non-reproducible from the relative-date form originally pasted here:

   ```
   $ git log -1 --format=%H 5f227969  # 2026-08-24
   5f227969ac4db2e3d60dc6f2d207f1c400b9dc64
   $ git log -1 --format=%H 8495ab0a  # 2026-09-01
   8495ab0aa8862bcb9c4c7110621d06ae6344b830
   $ git log -1 --format=%H d3bce229  # 2026-09-05, the census's own HEAD
   d3bce22910ff2ffbcec64e9396d85875b3ab3f31
   ```

   ```
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

   `histdiff.py` itself was a throwaway scratch script, never committed
   anywhere in this tree or on any branch — it does not exist to re-run
   today, a gap a fresh-context review correctly flagged as making the
   aggregate table unauditable as originally written. That review
   independently re-verified three of the seven named nil-widening
   retypings directly against git history at the three commits above,
   with no script involved; re-confirmed here against the same three
   commits, with the real declaration sites named:

   ```
   $ git show 5f227969:cosmic/rand.tl | grep -n 'function choice'
   96:local function choice(list: {any}): any
   $ git show d3bce229:cosmic/rand.tl | grep -n 'function choice'
   96:local function choice<T>(list: {T}): T | nil

   $ git show e16531d7:cosmic/zip.tl | grep -n 'function a:close'
   141:  function a:close()
   $ git show 5f227969:cosmic/zip.tl | grep -n 'function a:close'
   170:  function a:close(): boolean, string

   $ git show e16531d7:cosmic/quicksand/proxy/serve.tl | grep -n 'local function serve_forever'
   373:  local function serve_forever()
   $ git show 8495ab0a:cosmic/quicksand/proxy/serve.tl | grep -n 'local function serve_forever'
   376:  local function serve_forever(): boolean, string
   ```

   All three reproduce exactly. `5f227969` and `8495ab0a` are the
   census's own snapshot-boundary commits, not the commits that did the
   retyping — a fresh-context review caught this spec overclaiming
   direct agency ("retyped by X itself") where the commands only show
   the state at a boundary. The actual mutating commits, found and
   confirmed against `git show --stat`: `50665e0d` (2026-08-14, "zip:
   close is fallible, because close is where the archive lands") for
   `zip.Archive.close`, and `3053b87d` (2026-08-26, "quicksand/proxy:
   serve_forever returns a fallible effect") for `serve_forever`. Both
   land inside the windows the census counts them in — `50665e0d`
   before the `5f227969` (08-24) snapshot, `3053b87d` before `8495ab0a`
   (09-01) — which is the only claim these three spot-checks actually
   need to support. The remaining four named retypings and the full 30/20 aggregate
   are not independently re-derivable without rewriting the extractor —
   a real, stated limit on this fact's audit trail, not a claim to lean
   on beyond what these three commits and three spot-checks actually
   support.

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

## Handover

Both facts and the named test are now in «M5U2_X7wl»'s (`3IPXRRd2`)
own spec: the `## Goal` section carries the two measured facts
verbatim (retyping dominance, total silence under the pinned
checker), and `## Change`/`## Acceptance` name the new upgrade-shaped
`cosmic/teal_narrowing_test.tl` case (a `T | nil, string` retyping
refused with `STRICTNIL` at a concatenation and at a `local x: T`
initializer) as a second, distinct addition alongside the existing
index-shaped flip. Landed at `3IPXRRd2`'s commit `f724037` (`spec
3IPXRRd2`, 2026-09-06). No diff against `cosmic-lua/cosmic` — this
item's only output is that spec revision, which is the deliverable.
