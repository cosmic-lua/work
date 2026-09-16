--- The spec bar's doctrine page, split out of doctrine at its file cap.
--- Pure data; doctrine owns the topic name, order, and help rendering.

local BODY < const > = [[
A pullable spec carries one section — `## Change` — because
acceptance is not per-item: the repo's own gate passing (for cosmic,
`bin/cosmic --make ci` ending `ci: PASS`) is the one definition of
done every item shares, and proof specific to a change rides the
DIFF as a test or ratchet the gate runs. A gate outlives the sidecar
that asked for it; a sidecar command runs at most twice and dies
with the item. A bound worth enforcing permanently is a test or
ratchet IN THE DIFF, not a bullet a builder re-derives by hand.

`## Change` is what to build: files named, the shape of the change
in each, every decision made. Imperative and concrete — never
"improve", "investigate", or "support". And one mechanism, never two
— "either X or Y, the builder's call" hands a fresh window the
refiner's own decision plus the reading it took to make it; pick,
and put the alternative in `## Non-goals` or nowhere. A Change
names what to change and where to look — a file, a function, an
error string, a state or enum literal — as DIRECTION for the builder
to find and confirm against the tree, never as a location the spec
itself certifies: a `grep -n` hit or a line number quoted at
refinement time is a photograph of a tree that has already moved by
the time anyone reads it, and the builder re-finds the real thing in
seconds regardless of whether the spec quoted it. A Change that adds
a verb or a flag says what it does; the builder finds the wiring it
touches. A Change that reaches many sites says what the change is
FOR and lets the builder find them — `grep` or `cosmic --find` is the
builder's tool at build time, not a count the spec carries. When the
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

Direction, not measurement: this rule used to require every
tree-fact the spec relied on (a file's headroom under a line cap, a
pattern's match count, a function's callers) measured during
refinement and written into the prose WITH the command that produced
it, on the theory that a spec asserting things from memory is a real
and expensive failure mode — true, and still the reason a Change
names concrete direction rather than "improve" or "investigate". But
the rule wrote a snapshot of the tree into a document read hours or
weeks later, and every one of those facts decays: a stale count, a
stale line number, a moved file, a pasted `applied` line describing
a sweep that would now do something else. The verification it wanted
already happens, at the right time, for free: `help build` tells the
builder to re-run what the spec names before building, against the
tree they actually have, in seconds — and that re-run is now the
whole check, not a courtesy repeat of one already done at spec time.
A claim about BEHAVIOUR — what a verb prints, which branch a
condition selects, what a gate refuses — is still a claim to VERIFY,
never inferred from reading the source alone; it is verified there,
at build time, not carried into the spec as a paste. So a spec names
a file, a function, an error string, a behaviour as a pointer for
the builder to confirm — direction, never a fact the spec itself
certifies — and nothing in it requires a pasted command, a pasted
output, a match count, or a citation paired with a line number.
Spec-time measurement was the redundant half of a check that ran
twice; it is the half that rotted, so it is gone — say this plainly
here, so the next refiner does not read the missing paste as an
oversight and put it back. A Change that adds a cast, a
nil-admitting return, or a new source file still names the ratchet
rows it expects to add, so the builder's first gate is its last —
that is direction about what to expect, not a measurement to
re-derive.

A precondition is a DEPENDENCY, not prose. A Change whose earliest
valid start waits on a fact outside the tree — a release having
shipped, a lane gone green, a pin bumped — waits on the ITEM that
makes the fact true: file that item and `gitboard depend <THIS>
<THAT>`. `next` then skips this one and names what holds it, and
`take` refuses it, without anyone re-reading a criterion by eye. See
`help depends`.

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
