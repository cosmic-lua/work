--- The system of work, served by the tool: `gitboard help <topic>`
--- prints one of these pages, and the overview help lists them. The
--- pages carry DOCTRINE — what the verbs are for, the ordering, the
--- bars, and the judgment around them — while `help <verb>` stays the
--- mechanics. The `work` skill, on cosmic's own `main`, is only the
--- bootstrap and delegates everything else here, so the one source
--- for how to operate the board is the binary a session has already
--- built, and a doctrine change ships to every session with the next
--- sync.
---
--- Pure data: no git, no filesystem. `_work/doctrine_test.tl` pins
--- that every listed topic renders and that no topic shadows a verb.

--- One page. `body` is the prose; `title` is the one-line summary the
--- topic list prints beside the name.
local record Page
  name: string
  title: string
  body: string
end

local PAGES < const >: {Page} = {
  {name = "offline", title = "claim, work offline, and publish once",
    body = [[
Gitboard keeps authentication at the caller boundary: it never discovers, stores, or
brokers credentials. Bare transport commands prepare or print exact Git argv;
`--execute` runs those commands through ordinary caller-configured Git.
Acquire the work set from caller-fetched state:
  export GITBOARD_SESSION=$(gitboard session new)
  gitboard refresh --execute
  gitboard claim A B C
  # run its one printed `git push --atomic`, then
  gitboard refresh --execute
`claim A B C` prepares one parentless immutable claim-batch commit holding set, caller,
operation, and common two-hour deadline. Its unique append-only
`refs/heads/claim-batches/<batch-id>` names it. The batch ref and every first-parent
item bridge publish atomically; each bridge tree stores only the batch SHA and item
refs remain the CAS fences. ANY live
overlap, including this caller's claim, rejects all. Retry a changed set as a new batch;
use separate `renew` and `drop` for held claims. PREPARED and PUSHED grant no authority.
Only `refresh` seeing every ref confirms the batch. Work offline until its deadline.
Chain dependent board mutations in a durable clone-local draft:
  export GITBOARD_DRAFT=$(gitboard draft begin --print-id)
  gitboard new ...
  gitboard spec ...
  gitboard rank ...
  gitboard draft show
  gitboard publish "$GITBOARD_DRAFT"
  # run the one printed atomic push, then
  gitboard refresh --execute
Drafts overlay a frozen snapshot and publish each ref's original and final ids in one atomic push.
A rejected lease lands none; drafts never silently rebase. Claims stay outside drafts
because unconfirmed coordination grants no authority. `draft abandon` is local-only.
]]},
  {name = "system", title = "the board: states, order, exits, rules",
    body = [[
One prioritized queue of items in this repository (cosmic-lua/work),
operated only through gitboard verbs. An item's ROLE is its position
in the graph: the parentless item is the board; its children are the
outcomes; an item with open children is a container being decomposed;
and a childless item below the outcome level is workable. How the
queue orders itself, and what makes an outcome triage, is `help order`.

A rank change among OUTCOMES — putting new work above existing work —
belongs to the goal owner: it answers "which is the better cosmic".
Post the pair (in chat, or in the session's report when nobody is
watching) and keep working; the answer lands as a `rank` whenever it
arrives. Outcome prose lives in docs/goals.md on cosmic's own main;
reordering outcomes is a rank change plus a goals.md PR.

An open workable leaf is in exactly one of two states; everything
finer derives from facts the item already carries:

  todo   unclaimed. Pullable when its spec passes the bar (`help
         bar`); otherwise refining it toward the bar IS the work.
  doing  claimed. The claim is the lock and a lease: claim before you
         build, and a claim idle past its lease is anyone's again.
         Within doing the facts say what happens next: no PR — build;
         PR, no verdict — review at a distance; `request changes` —
         rework on the same PR; `accept` — merge, then `done`.

Two exits from doing, split by which side stopped. A gap in the ITEM
— a spec that cannot answer, a reopened decision, a falsified
premise — files the question as a CHILD of this item (`new --parent
<ID>`), then drops the claim: the item is a container until the
child resolves, and the child's `done` frees it with no further verb
(`help order`). A bare `drop` is the WORKER-side release — a dead
session, a spent budget — and asserts the item is fine to re-offer
as-is (`help drop`).

Claims provide mutual exclusion, not shared capacity. One parentless immutable batch
commit stores the facts once; its append-only batch ref and every item-history bridge
publish atomically or none does. Item refs remain the fences. Any live overlap refuses
acquisition. Work limits remain local. See `help offline`.
Work flows right to left — finishing beats starting — and that is
ONE derived order, not advice: every queue ranks stage first
(accepted, review, rework, building, lane repair, todo) and rank
order within a stage, age last (`help order`). Stage is
lexicographically supreme — no rank moves a todo item past a
waiting verdict, because an unreviewed diff is a wasting asset and a
hot pull's delay is at most one review. `next` offers the queue's
head and leaves lower-stage todo work unoffered while a review awaits.
Do what `next` names and ask again — acting moves the
board, so the second answer derives from the board the first left
behind. Stop when it says `none`: do not invent work. Beyond the
queue: triage what arrived, refine the top of todo, decompose an
undriven outcome — in that order.

Session identity: never pass --session — the tool derives a
unique-per-run identity from the environment, and an invented name
collides across runs, silently breaking the mutual exclusion. Two
exceptions: a review subagent names itself (review-<ID>-<unique>),
so the log never shows a builder accepting its own work, and an
orchestrator mints one distinct name per agent it spawns.

Hard rules:
- ALL work state lives in items here, moved and read through
  gitboard only — never GitHub labels, issue comments, notes docs,
  or TODO comments in a product tree. Issues are the inbound queue
  only. When the tool lacks a verb, work around it ONCE by editing
  the item file and committing, and file the missing verb as an
  item.
- claim before you build; losing a claim you
  went quiet on is the system working.
- the spec bar is never lowered to make an item pullable. --force exists
  for repair, not for flow.
- build the spec, not your memory of intent; a gap discovered
  mid-build goes back to the board as a child of the stuck item,
  never into the diff.
- nothing merges without a fresh-context review, and no session
  accepts its own work.
- findings become items, never widened diffs.
- every workable item has its place — rank it, attach it, or end
  it, however good the idea (`help order`).
- repo conventions are never relaxed: the repo's gate and its
  AGENTS.md bind every PR. When a convention keeps tripping
  sessions, the fix is a countermeasure item, never an exception.
- a mutation the board already holds is a no-op that succeeds.
]]},
  {name = "order", title = "how items are ordered",
    body = [[
An item's rank is a path: its position among its siblings at each
level down from the board, the one parentless item. Rank among
siblings is a position in a list the parent holds; siblings not in
the list follow it, by age. An outcome the board's list does not
position, and everything under it, is triage.

In practice: `rank ID --before|--after|--last` moves an item among
its siblings, an outcome against other outcomes the same way;
`new`/`attach --before X`/`--after X` places it there the moment it
arrives; an unranked outcome, and everything under it, is triage; an
unranked child still pulls, just after its ranked siblings.
]]},
  {name = "bar", title = "the spec bar: what makes an item pullable",
    body = [[
A pullable spec carries one section — `## Change` — because
acceptance is not per-item: the repo's own gate passing (for cosmic,
`bin/cosmic --make ci` ending `ci: PASS`) is the one definition of
done every item shares, and proof specific to a change rides the
DIFF as a test or ratchet the gate runs. A gate outlives the sidecar
that asked for it; a sidecar command runs at most twice and dies
with the item. An `## Acceptance` section, where a spec still
carries one, is the refiner's own worked proof that the Change's
claims held at measurement time — read once by the puller to
sanity-check the shape still holds and once by the reviewer to
spot-check a claim — never re-executed bullet by bullet as a second
gate. A bound worth enforcing permanently is a test or ratchet IN
THE DIFF, not a bullet a builder re-derives by hand.

`## Change` is what to build: files named, the shape of the change
in each, every decision made. Imperative and concrete — never
"improve", "investigate", or "support". And one mechanism, never two
— "either X or Y, the builder's call" hands a fresh window the
refiner's own decision plus the reading it took to make it; pick,
and put the alternative in `## Non-goals` or nowhere. A Change
that names a function or a string quotes the `grep -n` hit that
places it, and a state or enum literal quotes the vocabulary the
schema or record declares — a location read from memory is the
wrong turn that feels obviously right. A Change that adds a verb or
a flag lists its three wiring files by name — `_work/gitcommands.tl`
(the declaration), `_work/gitboard.tl` (the argv dispatch branch),
`_work/gitverbs.tl` (the `cmd_<verb>` entry) — because a builder that
finds them unnamed reads the whole dispatcher to decide whether it
may touch them. A Change over N sites states the PATTERN that
selects them and the count `cosmic --find PATTERN [PATH...]` printed
— never a list of file:line pairs a builder re-derives. When the
change sits near a frozen contract (a C boundary, error strings
and return shapes, verdict-line formats), name the wall — there,
or in an optional `## Non-goals` section. Walls are stated where
they exist, never filled in as ceremony. The test for every
sentence: could a competent but literal-minded session, with
nothing beyond this spec and the repo's AGENTS.md, get it wrong?
If yes, it is not ready.

Measured, not inferred: every tree-fact the spec relies on (a
file's headroom under a line cap, a pattern's match count, a
function's callers) is measured during refinement and written into
the prose WITH the command that produced it, so the puller re-runs
it in seconds and the reviewer can check the claim. A claim about
BEHAVIOUR — what a verb prints, which branch a condition selects,
what a gate refuses — is a prediction until a command has produced
it: reading the source is inference, and the wrong turns are never
guesses, they are readings that felt obviously true. So a
behavioural claim carries its command AND the pasted output.
Absence is behavioural too: a grep returning nothing establishes
that the PATTERN matched nothing, never that the thing is absent —
widen it, or name what the narrow one could miss. The same rule
covers removals: a Change that relocates or deletes a mechanism
names the sweep it ran for sites still asserting the old one. A
Change that adds a cast, a nil-admitting return, or a new source
file names the ratchet rows it will add, so the builder's first
gate is its last.

Ready when: a Change whose earliest valid start depends on a fact
outside the tree — a calendar day, a release having shipped, a lane
gone green, a pin bumped — states that fact as a command and the
output that means ready, in prose at the top of `## Change`: "Ready
when: `CMD` prints `OUT`." The tool checks it rather than a puller
reading it by eye — `next` skips a not-ready head and offers the
next candidate instead. A direct claim is only a lease, not proof of
readiness, so its caller must check the criterion before building.
No field, no date, no other verb: the criterion is
whatever the command prints, and it ages with the spec.

Sizing: one PR one session holds in its head (~400 changed lines is
the smell threshold, not a rule). An "and" between two independent
changes in `Change` means cut it in two. Prefer file-disjoint
siblings — two specs growing one file near a line cap collide at
the merge, a failure neither diff can see. Real landing order is a
rank (`help order`); research is an item whose deliverable is
recorded findings and follow-up items, not code.

Goal context is the parent chain — there is no Goal section.
Dependencies are children — there is no Enablement section.
Enablement is still the highest-leverage work: when the
same wrong turn appears twice, file the countermeasure as an
ordinary item, preferring a gate in core over a doc, and a doc over
a skill — gates transfer to every future session; prose does not.
]]},
  {name = "build", title = "building a claimed item",
    body = [[
1. Claim it (`claim ID`), publish the prepared batch, refresh until confirmed,
   then read `show ID` — the sidecar is the
   spec, and the item's verdict/pr fields carry any standing review
   state.
2. Re-run the spec's measured commands, including `Ready when`, before
   building — the queue ages faster than the tree stands still, and a
   direct claim proves exclusivity rather than readiness. Numbers moved
   but the shape holds: refresh them in place
   (`spec ID FILE --base BASE`) and proceed. A fresh fact that
   breaks the shape or reopens a decision: file the question as a
   CHILD of this item (`new --parent <ID>`), then drop the claim —
   the item is a container until the child resolves, and the
   child's `done` frees it with no further verb (`help order`). A
   bounce is a good outcome — the bar failing loudly instead of a
   silent wrong guess — and answering the question may well be your
   own next action; do that from the spec and the tree, not from
   what you remember wanting.
3. One acquisition = one fresh branch at the exact product base stored in
   its claim, named `work/<handle>/<claim-root-short>`. `worktree ID` creates
   it from already-present local Git data. Never stack a second item on the
   branch and never reuse an expired attempt's branch.
4. Build exactly the `## Change`; its stated walls hold. A scope
   question the spec cannot answer goes back to the board, never
   into the diff — having written the spec is not permission to
   reinterpret it mid-build.
5. Hand over the exact local product commit with `take ID --head SHA`
   (optionally `--url URL` for navigation). If the caller opens a pull
   request or inspects checks, it does so with its own authenticated tooling;
   Gitboard stores no provider fact and performs no provider request. The
   commit id is the whole durable evidence.
6. Rejoin the loop. Never merge unreviewed work, and never accept
   your own: the verdict comes from a fresh-context review.

Out-of-scope findings (a real defect, a stale doc, a gap the item
sits next to but does not own): search first — every item is a ref, so
`git grep -il '<phrase>' $(git for-each-ref --format='%(refname)'
refs/heads/items refs/heads/ended)` in the board checkout answers "already
filed?" — and cite the existing item rather than duplicate it; else
`new "title" --spec-file F` with one paragraph of evidence, unparented.
Filing is never refused. Then back to the item: never widen the diff
to cover a finding.
]]},
  {name = "review", title = "the fresh-context review and its verdicts",
    body = [[
Nothing merges without a verdict from a review at a DISTANCE from
the builder: a subagent whose context window never held the build.
Its brief carries the item id, the exact handed-over commit, and the process — not
the builder's reasoning, and not a summary of intent, which would
hand back the commitment a fresh window exists to be without. Emit
the brief with `brief review ID` rather than hand-writing one — it
mints and fills the exact session label this review claims under,
`review-<handle>-<orch8>` (`<orch8>` the first 8 characters of the
calling session's own identity, `show`'s "session: ..." line), and
repeats it on the brief's own verdict line so an orchestrator claims —
`claim ID --session <label>` — under that identical string BEFORE ever
spawning the agent the body goes to. A solo session reviewing without
an orchestrator instead self-names (`claim ID` under its own
review-<ID>-<unique>). Either way the reviewer's session reads the
spec off the board and the diff from local Git, and records the verdict
itself.

The posture is adversarial — the job is to make the diff fail, and
a review that only reads has verified nothing:

1. Mechanical checks belong to the exact handed-over commit. Inspect them
   through caller-owned tooling or run them locally; Gitboard neither queries
   nor records their state. What automation cannot see is the whole job: the
   diff must carry its own proof, so a claim the change makes that
   no test in the diff would catch regressing is a gap to quote.
2. The diff is the Change — everything present, nothing extra.
   Scope creep gets cut even when it is good; good ideas become
   items.
3. The walls held — frozen contracts unmoved, and any walls the
   spec states untouched.
4. Conventions hold — the repo's AGENTS.md binds; anything a gate
   should have caught but did not is itself a finding to file.
5. It serves the outcome — walk the parent chain to the outcome and
   judge the diff against it. A green gate on a change that misses
   the point means the SPEC was wrong: fix the spec, never wave the
   diff through.
6. It is the least thing — name any surplus concretely (a helper
   with one caller, generality nobody asked for) and have it
   removed before merge.

Mutation-test at least one guard the change adds: break what it
guards, watch the test go red, restore it. A gate that cannot be
shown to fail is decoration.

Three verdicts. Each names the exact commit with `verdict ID KIND --head SHA`.
`accept` — land that commit with caller-owned Git or provider tooling, then
`done ID --landed SHA`. `request changes` — report the concrete gaps outside
the board; the claimant reworks and hands over a new commit. `reject` — the
approach is wrong: abandon any external review,
record what was learned, clear the claim. A reject that reopens a
decision files the question as a child of the item, then drops the
claim: the item is a container until the child resolves, and the
child's `done` frees it with no further verb (`help order`).
Rejection is cheap by design; wrong work merged is expensive.
Research agents return recommendations; the caller applies them in the product
repository and hands over its exact commit through `take ID --head SHA`.
That commit must descend from the claim's product base. A result digest or
unrelated board item-ref commit is not a substitute. If no applying product
commit exists, no review brief is available: stop for caller preparation.
Research uses ordinary exact-head review; no result-only review template
or additional agent board-read instructions are emitted.

When a container's last child ends, verify the container's stated
outcome actually holds — run its observable test, not the
children's — then end it.
]]},
  {name = "orchestrate", title = "concurrent agents and the standing loop",
    body = [[
One orchestrator, N builders, and the board stays with the
orchestrator — agents never run board verbs, so no agent needs this
checkout or push rights to this board repository:

- Claim first, then spawn. `claim ID...` prepares one parentless immutable batch,
  its append-only ref, and one first-parent item bridge per member; all publish or none.
  Any live overlap, including your own, refuses acquisition: refresh and try a new set;
  use `renew` or `drop` for held claims. Only refresh grants authority. Use a distinct
  session per agent: `<kind>-<handle>-<orch8>` (`build`, `research`, `review`, `refine`
  or `decompose`; `<orch8>` the first 8 characters of YOUR OWN
  session identity, `show`'s "session: ..." line) — the same shape
  `brief KIND ID` mints and prints on its own verdict line, so reading
  that line before you spawn gives you the exact string to claim
  under. Embedding your own identity is what keeps two concurrent
  orchestrator sessions working the same item from minting the
  identical label and each reading `claim`'s exact-string lock as its
  own re-claim instead of a foreign one. A lost race is the lock
  working: take the next item.
- Disjoint or not at all. `next` names one item and cannot see what
  else you are taking; file-disjointness across the wave is your
  check, judged on the MERGE — a shared file with thin headroom
  under a line cap counts as shared. `show --todo 0` lists every
  pullable todo row with its repo, the whole set that judgment weighs
  — `show`'s own default trims the list to the top 8. Say what you
  skipped and why. Never split one item across agents to make it
  faster.
- One fresh worktree per agent: confirmed `claim ID`, then `worktree ID`, then
  `brief builder ID`, then spawn. `worktree` resolves ID's repo to a
  local checkout, branches and adds the worktree beside it — never
  detached, never nested inside another checkout — and bootstraps it,
  so nothing between the claim and the brief is done by hand: never
  `git worktree add` yourself, and never the Agent tool's own
  `isolation: worktree` option — either one skips the tool's own
  branch/path-reuse refusal and its bootstrap, handing an agent a
  checkout nobody warmed. `worktree`'s own verdict line names the
  path; `brief builder ID` reads the same path back into its
  "Where to work" section without it being retyped.
- A builder's worktree of the board repo is linked to the live clone;
  the tool refuses board writes there, so a builder never smoke-tests
  a verb outside the test suite's fixtures.
- The brief carries the spec verbatim — "read the board and do it"
  turns a specified item back into an interpretation. Emit briefs
  with `brief builder ID` / `brief research ID` / `brief review ID` /
  `brief refine ID` / `brief decompose ID` rather than hand-writing
  them: a hand-written brief drifts, and the emitted one already
  carries the spec, the item's coordinates, and the standing rules
  (ready PR with the Board: line, no pasted gate output, do-not-merge,
  the capture rule, the bounce rule). A brief may also be handed to an
  agent as `--out FILE`'s path, with the instruction "read it whole,
  it is your brief verbatim" — the file is exact where a pasted
  prompt may not be.
- Reconcile the wave. Finished work hands over its locally present commit with
  `take ID --head SHA [--url URL]`. Opening a pull request, pushing a branch,
  and checking automation are caller-owned authenticated operations. Dead
  (no handover commit):
  release the claim (`drop ID --why`, a worker-side reason) so the
  item is pullable again. Still running: leave it. Then the PRs are
  yours to watch — the agents are gone.
- Reviews fan out like builds: one fresh subagent per handed-over commit awaiting
  a verdict, each under its own minted `review-<handle>-<orch8>`
  label — `brief review ID` fills it into the body it hands the
  agent, so claim under the string its own verdict line names, all in
  the background. What the review needs is distance from the BUILDER —
  a window that never held the build — and a verdict that is one
  agent's alone; N reviewers on N different commits keep both. A row already
  carrying a foreign active whole-item claim is already claimed:
  skip it, never `--force`. What never fans out is refinement, because
  two parallel refiners decompose the same outcome twice.

The standing loop (a session invoked as an orchestrator with a
width N, three to five in practice) runs ONE bounded pass and ends
it. Never wait inside a pass — not for a wave agent, not for a
review agent, not for CI, not for an answer. Reviews outrank pulls; honor
`next` when forming each batch. Claim reviews first to keep completion ahead
of starts:

1. Run caller-owned fetches, `refresh`, then reconcile the previous wave.
2. Merge whatever carries an accept.
3. Claim and spawn a review for every item awaiting a verdict —
   one fresh subagent each, in the background, a distinct minted
   review session for each. They count against N first.
4. Fill the rest of the wave with builds: claim then spawn in the
   background, up to the smallest of N and what is actually
   disjoint. Zero agents is a legitimate pass.
5. Spare width goes to one or two refine/triage actions.
6. Report a terse ledger — one line per board action, one for
   anything posted for a human — and end the pass.

`none` from `next` is an answer, not a failure: report the named
bottleneck in one line and end the pass.
]]},
}

--- The topic names, in listing order.
--- @return {string} Names
local function names(): {string}
  local out: {string} = {}
  for _, p in ipairs(PAGES) do
    out[#out + 1] = p.name
  end
  return out
end

--- One topic's rendered page, nil for a name that is not a topic.
--- @param name string The topic name
--- @return string | nil Title line, blank line, body
local function page(name: string): string | nil
  for _, p in ipairs(PAGES) do
    if p.name == name then
      return ("%s — %s\n\n%s"):format(p.name, p.title, p.body)
    end
  end
  return nil
end

--- The topic list, one aligned row per topic, for the overview help.
--- @return string The rendered list, no trailing newline
local function listing(): string
  local width = 0
  for _, p in ipairs(PAGES) do
    if #p.name > width then
      width = #p.name
    end
  end
  local lines: {string} = {"topics ('gitboard help <topic>'):"}
  for _, p in ipairs(PAGES) do
    lines[#lines + 1] = ("  %s%s  %s"):format(p.name,
      string.rep(" ", width - #p.name), p.title)
  end
  return table.concat(lines, "\n")
end

local record doctrine
  names: function(): {string}
  page: function(name: string): string | nil
  listing: function(): string
end

local M: doctrine = {
  names = names,
  page = page,
  listing = listing,
}

return M
