# Design — an item declares intent; its history carries everything else

An item's spec says what to build. What was measured, what was
learned, and what happened along the way live in the item's own commit
history, never in its spec.

## The rule

A spec is prospective and is replaced. A measurement is retrospective
and is appended. Those are different artifacts with different write
semantics, and the tree holds only the first.

Everything below is that rule applied.

## What the sidecar had become

Read from the live board on 2026-09-12: 1342 items carry a `spec.md`
sidecar, 7.08 MB of markdown, **1149 distinct heading texts of which
1052 appear in exactly one item**. Eight headings carry the mass —
change 1039, non-goals 1021, evidence 797, goal 482, acceptance 428,
enablement 303, access 181, ready-when 47.

Two of those are read by code. `## Change` is the spec bar
(`_work/spec.tl`'s `READY_SECTIONS`) and `## Access` is the repo grant
(`_work/gitowner.tl`, `_work/gitready.tl`). The other six are named
only in prose instructions to a reading agent; no `.tl` file parses
them.

Three things follow from that, and together they are why the sidecar
is replaced rather than tidied.

**One heading, three incompatible readers.** `_work/spec.tl`'s
`sections` takes any heading level, case-insensitively, and ends a
section at a thematic break. `_work/overlap.tl`'s `change_section`
reimplements it narrowed to one heading. `_work/briefmeasure.tl`'s
`change_paths` matches `^##%s+Change%s*$` only — level two, exact case,
no trailing text — and ignores thematic breaks. Four bodies that all
pass the bar, read by the two path extractors:

    level-2 Change, backticked path   overlap [spec.tl]   briefmeasure [spec.tl]
    level-3 Change, same content      overlap [spec.tl]   briefmeasure []
    level-2, unbackticked path        overlap []          briefmeasure [spec.tl]
    path below a thematic break       overlap [spec.tl]   briefmeasure [spec.tl, overlap.tl]

**A convention nothing reads.** 47 items declare readiness under a
`## Ready when` heading and 38 as a `Ready when:` sentence inside
Change, with zero overlap. `_work.overlap.ready_when` reads only the
sentence, so 47 declarations are inert. Reading them shows the two
groups are not two spellings of one idea: the sentence form states a
start precondition, the heading form states acceptance criteria.

**Three artifacts in one file.** Classifying every sidecar's sections
by what they are:

    810  60.4%  spec                       corpus bytes:
    261  19.4%  spec+findings                spec                    71%
    100   7.5%  prose only, no headings      findings/working notes  21%
     71   5.3%  spec+findings+log            log                      8%
     36   2.7%  findings+log
     34   2.5%  spec+log
     22   1.6%  findings
      8   0.6%  log

**39.6% of sidecars carry more than one artifact class, and 8.4%
contain no specification at all.** The three largest are 91 KB, 48.5 KB
and 39 KB, and are almost entirely logs; the 91 KB one has 113
headings.

That is not authors being undisciplined. The spec vocabulary converged
on its own — across ten chronological deciles, change/non-goals/evidence
went from 62/68/35% to 95/91/81% while goal/acceptance/enablement
collapsed to 29/9/0%. The one-off tail is concentrated in the two
artifacts that were never given a schema to converge on.

The mechanism that put findings there is explicit. `_work/gittake.tl`
refuses a research handover with *"has no spec sidecar — a research
handover hands the spec over, and there is none"*, and records
`it.result = spec.revision(body)`. The deliverable could only ever
point at the spec, so findings were written into the spec.

## The schema

    refs/heads/items/<ksuid>  tree:
      meta            key: value lines — item state and declared facts
      spec/
        change.md     prose: what to build
        non-goals.md  prose: the walls
      order           ranked children

`meta` gains `touches`, `access` and `depends_on`, space-joined exactly
as `order`, `builders` and `speccers` already are; `target` unpacks into
`repo` and `base`; `key`, `result` and `verdict_spec` are gone.

`touches` is the files the change is expected to touch, **declared by
the refiner rather than scraped from prose.** It is what
`_work.overlap`'s collision detection and cap-headroom warnings read,
and declaring it deletes `looks_like_path`, `raw_paths_named`,
`change_section` and `change_paths` — four functions, three
disagreements. It is advisory: nothing refuses on it.

`access` is the repositories the work needs beyond the item's own
`repo`. Sampling 30 of the 181 `## Access` sections, they are already
one clause per repository, so a list of slugs loses nothing.

Both live in `meta` rather than under `spec/` because ownership is
enforced by which verb writes a field, not by tree position — `verdict`
is written only by `verdict`, `pr` only by `take` — and because
collision detection then costs no read at all: `store.list` already
loads every item's `meta`, so the batched whole-board spec read
disappears from `show` and `next`.

There is no `acceptance` field. Done is the repo's gate passing; a
behaviour worth guaranteeing permanently is a test or ratchet in the
diff, which outlives the sidecar that asked for it.

There is no `evidence` field. A measurement is retrospective.

There is no escape hatch. Content that is not prospective intent is a
log entry.

There is no `kind` field. What an item is follows from what it carries
and where it sits, the way role already follows from the graph.

## Why prose is blobs and fields are lines

Both serialization formats in the standard library were tested against
real spec content. `cosmic.literal` refuses lists outright — on write
*and* on read — which is what `_work/item.tl` means by *"the literal
domain has no lists."* And both it and `cosmic.json` round-trip prose
byte-exactly while writing it as one escaped line:

    return {
      ["change"] = "Rewrite `_work/spec.tl`.\n\n```\n$ grep -n \"X\" f.tl\n...",
    }

A 60-line Change becomes one unreadable line, destroying the `git diff`
these are reviewed through. So prose stays raw bytes in its own blob,
and the machine-read facts stay `key: value` lines in `meta`. Nothing
is serialized.

## The log is the commit

Every board mutation is already a commit on the item's ref, carrying a
committer date, an author, a subject naming what happened, and the
state after. The subjects are verb-and-operands — `spec <id>`,
`take <id> by <id>`, `verdict <id> accept by <id>` — and the message
**body is empty**: only 265 of 2414 spec commits carry any explanatory
text, and those are the ones where `--force --why` required a reason.

The narrative had nowhere to go, so it was written into the tree. A log
entry is a commit message body. Most entries already coincide with a
mutation, so the common case costs no extra object, and `gitboard log
ID` is `git log` on the ref.

The item's **outcome** is the body of the commit that resolved it, or
of the latest handover commit while it is open. That makes the
deliverable a commit in both cases — a product commit for a diff, a
board commit for research — so `result` has nothing left to hold.
Findings become immutable: a correction is a new entry, which is how
the corpus already works (`## correction — 2026-08-28` headings appear
in the churn data).

## Dependencies are their own relation

An item carries `depends_on`, a set of zero or more item ids. It gates
whether the item is pullable — `next` does not offer it and `take`
refuses it, naming the dependency — and it has **no effect on rank**,
which stays a position in the parent's list. Parentage says where in the
queue; dependency says whether this may start. A waiter stays workable
rather than becoming a container, so it keeps its place and reappears
the moment its last dependency resolves.

Stored as a space-joined `meta` line beside `order`, `builders` and
`speccers`, so readiness costs no read beyond the `meta` every
whole-board verb already loads. A cycle is refused by the mutation that
would create it and reported by `fsck`, bounded by the depth limit the
rank and flow walks already share.

Why a relation and not parentage: of the 21 distinct `Ready when:`
preconditions ever written, 16 are "a sibling item is done", several
naming the sibling and then writing a shell command to detect it because
there was nothing to point at. Across the board 30 items express a
dependency in prose against 31 distinct things depended on, and **5 of
those 31 are waited on by more than one item** — a shape parentage
cannot hold, since an item has one parent.

A precondition that is an external fact — a release carrying a merged
item, a pin naming that release — is itself work, so it is an item, and
every item waiting on it depends on that one item.

`fsck` gains one derived report: an item whose `change` names `«id»` as
blocking where that id is not in its `depends_on`.

## Migration

Format 5, one cutover, all 1360 refs in one atomic push, then the
migration module is retired — the same shape as the format-3 to
format-4 migration before it.

Per item: `## Change` and `## Non-goals` become `spec/change.md` and
`spec/non-goals.md`; paths and repos the refiner named become `touches`
and `access`; everything retrospective — evidence, findings, accreted
log entries, 28% of corpus bytes — becomes the body of **one migration
commit per item**, dated when it was moved rather than backdated to
dates it claims inside itself. It stays indexed by `find` and readable
through `git log`. Acceptance is dropped; it remains in history.

## The order these land in

Each is a child of the one after it, so the chain reads bottom-up the
way D45 ranks prerequisites.

1. **Doctrine and briefs agree.** Every template teaches the bar the
   gate enforces: `## Change`, with `## Non-goals` where a wall is at
   stake and `## Access` where the spec's text reaches another
   repository. Before this, the research and refine briefs
   contradicted each other inside one file — one taught a five-section
   bar including `## Goal` and `## Acceptance`, the other forbade
   `## Acceptance` — and both contradicted `READY_SECTIONS =
   {"Change"}`. Landed here, ahead of any format change, so the corpus
   stops drifting while the rest is built. `## Evidence` is untouched:
   the measured-evidence requirement stays, and its move to history
   waits on the mechanism item 2 builds.
2. **The format-5 reader and writer.** The `spec/` tree, the new `meta`
   keys (`touches`, `access`, `depends_on`, `target` unpacked), the
   `depend`/`undepend` verbs and their cycle check, `fsck` extended to
   the new shape, format 4 still readable.
3. **Release and pin bump.** `bin/gitboard.pin` names a release
   carrying (2), because no clone can operate a format-5 board until
   its pinned build understands one.
4. **The migration.** Classify and rewrite every ref, one atomic push,
   bump the marker.
5. **Retire what is now dead.** The format-4 reader, `spec.revision`
   and its two callers, `result`, `verdict_spec`, `key`, the four path
   parsers, and `gitshow`'s unreachable verdict-moved branch.
