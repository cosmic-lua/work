# verbs: split the spec on write, declare dependencies, gate on them

## Change

Depends on `02-tree-and-fields`: that item lands the format-5 tree, the
`touches`/`access`/`depends_on` fields and `itemtree.Spec`, and this one is the
first thing that writes and reads them through a verb.

### `spec ID FILE` splits one markdown file into the two blobs

`_work/spec.tl` gains `split`, the inverse of `02-tree-and-fields`' `document`:

```
--- @param body string One markdown file's text
--- @return itemtree.Spec | nil The two blobs
--- @return string The refusal, naming the offending heading
local function split(body: string): itemtree.Spec | nil, string
```

It does NOT reuse `sections` (`_work/spec.tl:42`,
`local function sections(body: string): {string: string}`). That scanner is
level-blind and thematic-break-sensitive, which is two of the three
disagreements D47 measured, and reusing it here would truncate a `## Change`
at its first `###` subheading and refuse the subheading as an unknown section.
`split` is its own scanner, three rules:

- **fence-aware.** A line inside a ``` fence is content, never a heading — a
  spec that quotes `## Change` inside a pasted command's output is ordinary.
- **level-aware.** A section starts at a heading whose lower-cased text is
  `change` or `non-goals`, at whatever level the file spells it, and runs until
  the next heading at the SAME or a shallower level (no more `#` than the
  opener). A deeper heading inside it is content, so a Change with `###`
  subsections keeps all of it.
- **thematic breaks are content.** A `---` line does not end a section; a table
  rule or a separator inside a Change stays in the Change.

It returns `change` and `non_goals` from those two sections and REFUSES,
rather than dropping, anything else carrying content: a section-level heading
whose text is neither, and non-blank text before the first heading. The refusal
names the heading and where the fact now lives, one line per case:

- `## Access` → `access is a declared field now: gitboard set ID --access OWNER/NAME`
- `## Evidence`, `## Goal`, `## Acceptance`, `## Enablement`, `## Ready when`
  and anything else → `<heading> is not a spec section — a measurement or a
  narrative is a log entry, and a dependency is `gitboard depend`

This is the mechanism behind D47's "there is no escape hatch": without the
refusal the retired vocabulary simply reappears. The headings it will refuse are
the ones the corpus actually carries, measured over the 1371 item refs' spec
blobs:

```
$ cd o/board && git for-each-ref --format='%(refname)' \
    'refs/remotes/origin/items/*' 'refs/remotes/origin/ended/*' \
    | sed 's|$|:spec.md|' | git cat-file --batch > /tmp/specs
$ for h in "## Change" "## Non-goals" "## Evidence" "## Access" "## Goal" \
    "## Acceptance" "## Enablement" "## Ready when"; do \
    printf '%-16s %s\n' "$h" "$(grep -c "^$h *$" /tmp/specs)"; done
## Change        1046
## Non-goals     1026
## Evidence       802
## Access         186
## Goal           479
## Acceptance     423
## Enablement     304
## Ready when      47
```

`_work/gitspec.tl` (146 lines) uses it. `cmd_spec` (`_work/gitspec.tl:78`,
`local function cmd_spec(s: store.Store, id: string, file: string,`) reads FILE
at `:103` (`local body, rerr = fs.read(file)`), then calls `spec.split(body)`
and returns `gate.verdict_line("spec", false, serr)` on a refusal. The
compare-and-swap base at `:107`-`:111` compares against
`spec.document(store.read_spec(s, id))` — one text against one text, the same
`gate.base_refusal(current, base or "", id)` call unchanged. The unchanged-spec
short-circuit at `:112` (`if body == current then`) compares the two `Spec`
records field by field. `diffstat` (`:50`) is fed the two documents, so its
`(+%d/-%d lines)` verdict at `:133` keeps meaning what it did.

`_work/gitgraph.tl`'s `cmd_new` (`_work/gitgraph.tl:127`,
`local function cmd_new(s: store.Store, title: string, parent: string,`) takes
`spec: itemtree.Spec | nil` in place of the body string, and the `--spec-file`
read in the dispatcher (`_work/gitboard.tl:337`, `local spec_file = d.parsed.values["spec-file"]`)
splits the file the same way, printing the same refusal.

### `depend ID ON` and `undepend ID ON`

New module `_work/gitdepend.tl`, beside `_work/gitspec.tl` for the same reason
that one is separate — it moves the DEFINITION of work, not its motion:

```
local function cmd_depend(s: store.Store, id: string, on: string,
    session?: string, force?: boolean, why?: string): integer
local function cmd_undepend(s: store.Store, id: string, on: string,
    session?: string, force?: boolean, why?: string): integer
```

Both read the board once with `store.list(s)` and index it with
`item.by_id(all)` — the shape `_work/gitrank.tl:186`
(`local all, aerr = store.list(s)`) and `:191` (`local it = index[id]`) already
use, and safe to save from now that `02-tree-and-fields` hydrates the three
lists through `_work/cachequery.tl`. Refusals, each a
`gate.verdict_line("depend", false, ...)`:

- `on` names no item: `no item <on>`.
- `on == id`: `an item cannot depend on itself`.
- either item is done (`not item.is_open(it)`): `%s is done (%s) — a finished
  item's dependencies are history, not a repair target`, the wording
  `_work/gitrank.tl:196` already uses for rank.
- a cycle: `on` reaches `id` through `depends_on`. Walk it breadth-first from
  `on` over `index`, bounded by `item.MAX_DEPTH` (`_work/item.tl:13`,
  `local MAX_DEPTH < const > = 16`) hops as D48 requires, and refuse with
  `depending on %s would close a cycle: %s` naming the handles on the path.
- `force`/`why` go through `gate.force_refusal(frc, rsn)` and
  `gate.commit_and_publish`'s own claim gate exactly as
  `_work/gitspec.tl:82` and `:123` do; nothing here has a force-only path of
  its own.

A dependency already present (or already absent, for `undepend`) is a
success that writes nothing, in the shape of `_work/gitspec.tl:112`
(`if body == current then`): `%s already depends on %s — nothing written`.

The write is one `gate.commit_and_publish(s, it, nil, ("depend %s on %s"):format(...), "depend", nil, session)`
— only the waiter's ref moves, since `depends_on` lives on the waiter. Its
subject is verb-and-operands like every other, so `git log` on the ref reads as
the board's log.

Wiring, the three files:

- `_work/gitcommands.tl` (391 lines) — the declaration: two `CSPEC` entries
  after the `spec` entry at `_work/gitcommands.tl:170`
  (`{name = "spec", summary = "replace ID's spec sidecar with FILE",`), with
  `usage = "ID ON [options]"`, the `PREPARES_ONLY` suffix every mutation's
  summary carries, and the flags `dir_flag()`, `--session`, `--force`, `--why`
  copied from the `spec` entry's own flag list at `:175`-`:182`.
- `_work/gitboard.tl` (478 lines) — the argv dispatch: a branch after
  `_work/gitboard.tl:399` (`if d.command == "spec" then`) resolving `ID` (the
  `local id, rerr = resolve_id(s, input)` the shared tail already did) and `ON`
  through the same `resolve_id` the `attach` branch uses at `:378`, then
  `claimcli.resolve_optional_caller` as `:405` does.
- `_work/gitverbs.tl` (362 lines) — the `cmd_<verb>` entry: re-export
  `cmd_depend = gitdepend.cmd_depend` and `cmd_undepend = gitdepend.cmd_undepend`
  in the `record gitverbs` at `:347` and the table at `:357`, the way
  `_work/gitverbs.tl:359` (`  cmd_done = gitdone.cmd_done,`) already re-exports
  a verb whose body lives in its own module.

### `next` does not offer a blocked item, and says which dependency holds it

`_work/gitready.tl`'s `ready_problems` (`_work/gitready.tl:83`,
`local function ready_problems(s: store.Store, it: item.Item,`) gains one loop
after the spec-bar gaps at `:119` (`for _, gap in ipairs(flow.ready_gaps(spec_body)) do`):
for each id in `it.depends_on` that is absent or still open, one line —
`depends on %s (%s), which is not done yet`, naming the handle
(`_work.tail.handle`) and the dependency's title. That one addition gates `take`,
because `_work/gitverbs.tl:183` (`local problems = gitready.ready_problems(s, it)`)
is the take gate.

`next` skips such an item instead of offering it. `_work/action.tl:150`
(`local function passes_bar(ranked: boolean, id: string, specs: Specs): boolean`)
takes the `Index` of items it is already walking and returns false when any id
in `depends_on` is absent or open; its one caller is `_work/action.tl:267`
(`local pb = passes_bar(row.ranked, row.id, specs)`).

A silent skip is the failure D48 names — "a session reading that needs to see
which dependency holds each one, or it looks like a bug" — so the skip is
counted and named, in the exact shape `ci_running`/`ci_names` already has.
`record Phased` (`_work/action.tl:77`) gains `blocked: integer` and
`blocked_names: string` beside `ci_names` (`:99`, `  ci_names: string`), both
filled from the same loop that counted them, and `phased_action` (`:176`) gains
a `none` branch before the final fall-through at `:392`, modelled on the CI one
at `:373` (`reason = ("%d item(s) await CI before a review is worth claiming: %s")`):
`("%d item(s) wait on a dependency and nothing else fires: %s"):format(ph.blocked, ph.blocked_names)`.
Nothing else renders `Phased`'s counters — `grep -rn "ci_names" _work/*.tl`
outside `_work/action.tl` matches nothing — so this branch is where a session
sees it.

### `new` and `set` accept the declared fields

`set` (`_work/gitcommands.tl:153`, `{name = "set", summary = "repair ID's title, repo and/or base "`)
gains `--touches PATH` and `--access OWNER/NAME`, both repeatable
(`d.parsed.lists`, the shape `worktree`'s `--ref` already uses at
`_work/gitboard.tl:415`, `d.parsed.lists["ref"] or {}`), each occurrence one
entry, and each flag REPLACING the field rather than appending — one mechanism:
`set` repairs a field to what the caller states. `new` (`:93`) gains the same
two. `depends_on` is NOT settable here: it has its own verb, because the cycle
check belongs to one place.

`cmd_set` (`_work/gitgraph.tl:389`,
`local function cmd_set(s: store.Store, id: string, title: string | nil,`)
takes the two lists as `{string} | nil` — nil meaning untouched, an empty list
meaning cleared — and keeps its existing at-least-one-option refusal, now
counting four options. `cmd_new` takes them alongside `repo`. An `--access`
value is validated as `owner/name` by the pattern `_work/item.tl:327`
(`if (it.repo or "") ~= "" and not it.repo:match("^[%w%-%.]+/[%w%-%._]+$") then`)
already holds `repo` to; `--touches` takes any non-blank token with no spaces
(a space-joined `meta` line cannot hold one) and is otherwise unvalidated,
because D47 makes it advisory: nothing refuses on it.

### Doctrine, which is where the two relations are explained

`gitboard help order` (`_work/doctrine.tl:145`,
`{name = "order", title = "how items are ordered",`) states rank and says
nothing about readiness. D48 asks for readiness beside it rather than inside it:
add one page to the `PAGES` list (`_work/doctrine.tl:23`,
`local PAGES < const >: {Page} = {`), `{name = "depends", title = "what makes an item startable"}`,
stating that `depends_on` is a set of item ids, that it does not move rank, that
`next` skips and `take` refuses while one is unresolved, that a waiter stays
workable rather than becoming a container, and that a precondition which is an
external fact — a release, a pin — is itself an item to depend on.

Two doctrine passages now contradict the verb and are replaced by a pointer to
that topic:

- `_work/doctrine_bar.tl:91` (`Ready when: a Change whose earliest valid start depends on a fact`)
  through the end of that paragraph at `:101`: the convention is gone.
  The mechanism still RUNS until `06-retire` deletes it — the pure evaluator
  `_work/overlap.tl:228` (`local function ready_when(body: string): string | nil`)
  and its live half `_work/gitreadywhen.tl` (57 lines,
  `local function skip_not_ready(decided: Action, specs: action.Specs): string, Action`),
  hooked in at `_work/gitview.tl:23` (`local readywhen = require("_work.gitreadywhen")`)
  — so this is a doctrine change, not a behaviour change; the prose that
  replaces it says a precondition is a dependency and names `gitboard depend`.
- `_work/doctrine.tl:175` (`child's `done` frees it with no further verb (`help order`). A`)
  and the identical sentence at `:256` teach parentage-as-dependency, the
  routing D48 supersedes: a question that blocks an item is still filed as an
  item, and the waiter now `depend`s on it instead of adopting it.

### Tests and the ratchet

New `_work/gitdepend_test.tl` covering each refusal, the no-op, and a two-hop
cycle; `_work/spec_test.tl` for `split`'s accept and refuse cases, one per
refused heading in the measured list above; `_work/gitspec_test.tl`,
`_work/action_queue_test.tl` (the skip and the `none` reason),
`_work/gitgate_test.tl` (its `ready_problems` cases at `:325`, `:337` and
`:347`), `_work/gitgraph_test.tl` and `_work/doctrine_test.tl` for the rest. `_work/gitboard_test.tl` covers the two new dispatch branches, and
`gitboard help` output is generated from the CLI, so the help test needs no new
expectations beyond the two verbs appearing. Add `.cosmic-coverage` rows for
`_work/gitdepend.tl` and hand-edit the rows this moves — `_work/spec.tl`
(`{["covered"] = 58, ["total"] = 60}`), `_work/gitspec.tl`, `_work/action.tl`,
`_work/gitready.tl` — rather than running `--make coverage --baseline`.

## Non-goals

- Nothing reads `touches` or `access` yet. `_work/overlap.tl`'s collision
  detection and `_work/briefmeasure.tl`'s headroom table keep extracting paths
  from prose, and `_work/gitready.tl:61`
  (`local function undeclared_repos(it: item.Item, body: string): {string}`)
  keeps reading `## Access` out of the text, because no item carries the fields
  until `05-migration` fills them. `06-retire` switches the readers and deletes
  the extractors.
- No `fsck` report on dependencies here. The cycle refusal at the mutation is
  this item; D48's derived report — a `change` naming an id as blocking that is
  not in `depends_on` — needs `touches`-era prose and lands in `06-retire`.
- The board cannot be operated with these verbs until `05-migration` has run:
  `02-tree-and-fields` set the marker this build demands to `5`, and the live
  board reads `4`. Every test here runs against a fixture board
  (`_work/fixture.tl`), never the live one.
- No change to rank, to `attach`, or to how a container's role is derived. A
  waiter stays workable by doing nothing: `depends_on` is not parentage.

## Access

- cosmic-lua/cosmic — `docs/decisions/d47-dependency-is-its-own-relation.md`
  (the relation, the refusals, and the no-effect-on-rank rule this implements)
  and `docs/decisions/d46-spec-declares-intent-only.md` (the two prose blobs and
  the no-escape-hatch rule the `split` refusal enforces).
