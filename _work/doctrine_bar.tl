--- The spec bar's doctrine page, split out of doctrine at its file cap.
--- Pure data; doctrine owns the topic name, order, and help rendering.

local BODY < const > = [[
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
wrong turn that feels obviously right. The same rule covers any
bare file:line citation of quoted source text, wherever it sits —
an `## Evidence` paragraph citing a fact as much as `## Change`
naming a function: pair the line number with a short,
still-`grep`-able literal string from that exact line, a
distinctive substring of the quote itself is enough, no new tooling
and no new section. A sibling item landing between refinement and
pull moves line numbers but rarely rewrites the line itself, so the
string still finds what the number alone would strand. Before:
`_work/example.tl:54-56` beside the quoted sentence. After: the
same quote plus `grep -n "the quoted phrase" _work/example.tl` —
the number may go stale, the grep hit does not. A citation with a
number but no anchor string is under the bar the same way an
unmeasured claim already is. A Change that adds a verb or
a flag lists its three wiring files by name — `_work/gitcommands.tl`
(the declaration), `_work/gitboard.tl` (the argv dispatch branch),
`_work/gitverbs.tl` (the `cmd_<verb>` entry) — because a builder that
finds them unnamed reads the whole dispatcher to decide whether it
may touch them. A Change over N sites states the PATTERN that
selects them and the count `cosmic --find PATTERN [PATH...]` printed
— never a list of file:line pairs a builder re-derives. A Change
whose acceptance is a sweep — a `--rewrite … --apply`, a `--fix`,
any command whose output is the diff — pastes that command's own
output from a dry run at spec time: the `applied`/`refused` line, or
the refusal, not only the `--find` count that named its sites. A
paste of `0 applied` or a refusal is itself proof the spec is not
ready — the sweep found nothing to change, or would not run at all.
When the
change sits near a frozen contract (a C boundary, error strings
and return shapes, verdict-line formats), name the wall — there,
or in an optional `## Non-goals` section. Walls are stated where
they exist, never filled in as ceremony. The test for every
sentence: could a competent but literal-minded session, with
nothing beyond this spec and the repo's AGENTS.md, get it wrong?
If yes, it is not ready.

A `## Change` that alters the shape of a committed tracking file
(a TSV, a baseline `.tl`, or a `.cosmic-*` floor) states how its
existing rows reach the new shape: a first-run migration the
change performs, an exact one-off command, or a rewrite committed
with the change.
The caller checks this before building; a missing plan means stop
and refine the spec, not invent a bridge.

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
]]

local record doctrine_bar
  BODY: string
end

local M: doctrine_bar = {
  BODY = BODY,
}

return M
