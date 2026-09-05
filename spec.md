## Change

Friction log for the board reshape of 2026-09-05: three agents, one
per outcome group, filed containers, attached ~90 items, and ranked
the outcomes' children. Numbers: roughly 180 tool calls across the
three, no lost-push races, zero `gitboard` refusals from a verb
behaving wrongly, and about 40 minutes of the total spent on the
first entry below. Countermeasures are filed as their own items
where the bar is met; this log ends when each is filed or judged
not worth it.

### no verb lists an item's children

Goal: enumerate an outcome's children to group and rank them.
Happened: all three agents walked every `refs/heads/items/*` ref by
hand (`git show <ref>:meta`, ~290 reads each), because `show ID`
prints one item's fields and history and the board view lists only
todo, doing, and triage. Cost: ~15 tool calls and several minutes per
agent, three times. Contributed: `X9Mff3np` (tree/check cited by 17
specs) and `3IuczDeN` (no read-only verb filters by state and rank)
already name this. Countermeasure: `show ID` lists the item's open
children in rank order under a `children:` heading; a listing verb is
the read-model design's `queue`/`outcomes` views rendered.

### done items stay on refs/heads/items and inflate parent scans

Goal: trust a child count. Happened: parent scans counted 93 under G8
where 62 were open; 31 carried a `resolution`. Cost: one extra
full-board pass per agent to learn that a done item keeps its ref.
Contributed: nothing documents that `ended/` is legacy and a done item
stays where it was. Countermeasure: the `children:` render above shows
only open children, and `help system` says where a done item lives.

### attach leaves the old parent's order entry, and fsck counts it

Goal: move a positioned child to another parent. Happened: every
agent that moved a positioned item left a stale entry in the old
parent's `order`, `fsck` reported each as a problem (8 at one point),
and two agents tried to hand-edit the parent's `order` blob through
git plumbing, which the harness refused. Cost: ~10 minutes each and
a mis-read of the board's health. Contributed: the design chose
"stale entries are ignored on read" to keep `attach` a one-item write,
and `fsck` reports them in the problem count. Countermeasure: filed —
`attach` prunes the old parent's entry in the same publish.

### rank refuses --before X when X is unpositioned, with no --first

Goal: position the first child of an outcome nobody had ranked.
Happened: `rank ID --before X` refused because X had no position; the
answer (`--last` places the first entry) is only inferable from the
refusal. Cost: one wrong turn per agent. Countermeasure: `help rank`
says `--last` is how a first entry is made, or a `--first` flag.

### new prints board-wide similarity hits for every container

Goal: file seven containers. Happened: every `new` printed `similar:`
lines against items in unrelated outcomes or already done. Cost: a
few seconds each, seven times. Countermeasure: none filed; noted
because it recurred on every create.
