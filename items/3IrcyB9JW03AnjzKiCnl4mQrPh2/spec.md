## Evidence

The original friction report, «NJCj_HQIX», records six re-review rounds on
two items requiring hand-suffixed session labels and edits to as many as
three occurrences in each brief.

Measured against `5222c8c4070e15e4f1a8a52493a6c43cf4780f29` in
`/Users/wcm/Documents/Codex/2026-09-08/ok-now-that-we-ve-cleaned/wt/work/l4mQrPh2/0be971a0d3f2`.

The earlier “current pr” grouping is obsolete. The following source
measurement locates the current seams:

```sh
rg -n 'local LABEL_KIND|local function mint_label|local label = mint_label|local function history|local function parse_subject|legacy PR verdict|Prior verdicts remain' _work/brief.tl _work/publish.tl _work/events.tl _work/gitverdict.tl _work/gittake.tl
```

```text
_work/brief.tl:53:local LABEL_KIND < const >: {string: string} = {
_work/brief.tl:81:local function mint_label(kind: string, handle: string): string
_work/brief.tl:370:  local label = mint_label(kind, tail.bare(it.id))
_work/publish.tl:271:local function history(s: store.Store, id?: string): {Event} | nil, string
_work/events.tl:62:local function parse_subject(subject: string): Subject
_work/gitverdict.tl:119:    "REFUSED: legacy PR verdict is disabled — inspect checks externally "
_work/gittake.tl:69:  -- Acceptance belongs to one commit. Prior verdicts remain in item history;
```

`sed -n '49,89p' _work/brief.tl` shows that LABEL_KIND and mint_label form
one self-contained section; its only dependency outside that section is
`_work.session`. `rg -n 'mint_label\(' _work -g '*.tl'` finds only the
definition at 81 and cmd_brief's call at 370. The existing exported
`brief.mint_label(kind, handle)` also remains an API compatibility wall.

```sh
wc -l _work/brief.tl _work/brief_test.tl _work/brief_review_script_test.tl
```

```text
487 _work/brief.tl
461 _work/brief_test.tl
234 _work/brief_review_script_test.tl
```

The header of `_work/brief_review_script_test.tl` (read with
`sed -n '1,12p' _work/brief_review_script_test.tl`) already documents the
sibling-test-file seam used to keep brief tests below the cap.

A hermetic probe exercised the current commit-handover and verdict module
entry points against throwaway Git repositories, then read
`publish.history(s, id)` before and after `cache.rebuild`. It recorded
request-changes on A, handed over B, recorded accept on B, and handed over A
again. It also exercised the existing events parser on synthetic legacy
PR/result subjects. These are existing-storage observations, not a claim
that the new numbering behavior already exists.

Probe command used:
```sh
TEST_TMPDIR=/tmp/l4mq-refine.0B0Q7S sh /Users/wcm/Documents/Codex/2026-09-08/ok-now-that-we-ve-cleaned/wt/work/lmuuJdtZ/6a5eec6618fc/o/bin/cosmic /tmp/l4mq-refine-probe.lua
```

Output:
```text
verdict counts: initial=0 after-new-head=1 after-second-verdict-and-new-head=2
current state: pr=0 verdict=""
cache history count=2
existing mint_label=review-a1b2c3d4-01234567
parse: verdict pr=17 head=""
parse: verdict pr=0 head=""
parse: board: pr=0 head=""
```

The probe source is reproduced below so this evidence does not depend on
the lifetime of the temporary file. Run it with a fresh TEST_TMPDIR and a
verified Cosmic runtime; it changes only its temporary fixture repositories.

```lua
local check = require('cosmic.check')
local flow = require('_work.commit_flow_fixture')
local verdict = require('_work.gitverdict')
local store = require('_work.store')
local publish = require('_work.publish')
local events = require('_work.events')
local cache = require('_work.cache')
local brief = require('_work.brief')
local env = require('cosmic.env')
local function count(s, id)
  local n = 0
  for _, event in ipairs(check.must(publish.history(s, id))) do
    if events.parse_subject(event.subject).verb == 'verdict' then n = n + 1 end
  end
  return n
end
local report = print
_G.print = function() end
local s, id, p = flow.fresh('round-refinement')
assert(flow.claim(s, id, flow.BUILDER, p) == 0)
assert(flow.handover(s, id, flow.BUILDER, p, p.head) == 0)
local zero = count(s, id)
assert(flow.claim(s, id, flow.BUILDER, p, 'drop') == 0)
assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
assert(verdict.cmd_verdict_commit(s, id, 'request changes', p.head,
  flow.REVIEWER, false, '', p.root) == 0)
assert(flow.claim(s, id, flow.REVIEWER, p, 'drop') == 0)
assert(flow.claim(s, id, flow.BUILDER, p) == 0)
assert(flow.handover(s, id, flow.BUILDER, p, p.next_head) == 0)
local one = count(s, id)
assert(flow.claim(s, id, flow.BUILDER, p, 'drop') == 0)
assert(flow.claim(s, id, flow.REVIEWER, p) == 0)
assert(verdict.cmd_verdict_commit(s, id, 'accept', p.next_head,
  flow.REVIEWER, false, '', p.root) == 0)
assert(flow.claim(s, id, flow.REVIEWER, p, 'drop') == 0)
assert(flow.claim(s, id, flow.BUILDER, p) == 0)
assert(flow.handover(s, id, flow.BUILDER, p, p.head) == 0)
local it = check.must(store.load(s, id))
local two = count(s, id)
assert(store.close(s))
local c = check.must(cache.rebuild(s.root))
assert(cache.close(c))
local warm = count(s, id)
assert(env.set('GITBOARD_SESSION', '0123456789abcdef'))
local old = brief.mint_label('review', 'a1b2c3d4')
_G.print = report
print('verdict counts: initial=' .. zero .. ' after-new-head=' .. one .. ' after-second-verdict-and-new-head=' .. two)
print('current state: pr=' .. it.pr .. ' verdict=' .. string.format('%q', it.verdict))
print('cache history count=' .. warm)
print('existing mint_label=' .. old)
for _, subject in ipairs({'verdict a1b2c3d4 accept pr:17 by legacy',
  'verdict a1b2c3d4 reject result:abcdef0 by researcher', 'board: legacy migration line'}) do
  local parsed = events.parse_subject(subject)
  print('parse: ' .. parsed.verb .. ' pr=' .. parsed.pr .. ' head=' .. string.format('%q', parsed.head))
end
assert(store.close(s))
```

## Change

Make review labels a deterministic ITEM-WIDE completed-verdict counter.
This replaces PR-scoped counting; it deliberately does not reset at a new
handover head. Rework normally changes the head, so current-head counting
would reproduce the round-one collision this item fixes.

1. Add `_work/brief_label.tl` as the cap-safe extraction of the existing
   LABEL_KIND/mint_label section and its session dependency from
   `_work/brief.tl`. Preserve the exact unsuffixed base-label behavior,
   including kind mapping, session.resolve(nil), first-eight identity
   characters, and the existing empty-prefix fallback. Preserve the
   existing exported `brief.mint_label(kind, handle): string` signature
   and its unsuffixed result by delegation. Update the moved documentation
   to distinguish that base formatter from the history-aware review label.
   Do not extract unrelated template, measurement, or review-selection code.

2. In the new helper, obtain review history through the existing
   `publish.history(s, it.id)` item-scoped read. For each returned event,
   use the existing `events.parse_subject(event.subject).verb`
   classification. Count exactly those events whose verb equals
   `"verdict"`, once per returned event. Do not deduplicate by product
   head, session, abbreviated event SHA, verdict kind or PR number.
   Do not parse head prefixes, consult current scalar verdict fields, query
   the events table directly, or introduce a second Git-history reader.

   Let n = count + 1. For n=1 retain
   `review-<handle>-<orch8>` exactly. For n>1 append `-<n>` in decimal,
   e.g. two prior verdict events produce `review-<handle>-<orch8>-3`.

   This count is over the lifetime history of this item ID. It does not
   reset on new handover heads, request changes, reject, cleared standing
   verdicts, URL edits, drop/reclaim, spec edits, a new orchestrator session,
   or a switch between commit and research review. A different item starts
   its own count. Repeated briefs against unchanged history return the same
   label: generating a brief does not allocate/reserve or increment a round.
   Failed/refused verdict attempts add no persisted event and do not count.

   Include legacy PR-keyed verdict events and historical result/research
   verdict events when the existing parser classifies their leading verb
   as `verdict`, even when their head is empty. Do not filter by
   `it.pr`, `it.result` or `it.handover_head`. Subjects the parser
   classifies otherwise (including `board:`, prose containing “verdict”,
   and take/spec/drop events) do not count. This is backward-compatible
   history consumption, not restoration of legacy PR/result verdict APIs.

3. Integrate the history-aware helper only in cmd_brief's `kind == "review"`
   path, after its existing item/spec/handover checks and before filling or
   writing the brief body. Both commit-review templates and the existing
   research-review template use the same rule. Resolve the label once and
   reuse that exact value for REVIEW_SESSION, embedded verdict commands,
   the closing claim-it-as label, and the brief content emitted through
   --out. Do not change the caller's output filename.

   A history read failure must return a nonzero `gitboard-brief:` refusal
   containing the underlying error; do not print a successful brief,
   truncate/write the requested output file, or silently mint round 1.
   Non-review kinds must not acquire a history read at all.

4. Add `_work/brief_label_test.tl` for the new label-focused coverage,
   following the existing sibling-test-file precedent. Leave the existing
   `_work/brief_test.tl` tests in place; do not relocate unrelated cases
   or create a shared fixture framework. Use existing fixture/storewrite
   helpers and a small capture helper local to the new test file.

   The new tests must enforce:
   - Zero prior verdicts gives the exact unsuffixed label (not a prefix
     match that would also accept a trailing -1); two verdicts gives -3.
     Check body session, embedded verdict command and closing claim label,
     including --out output, against the SAME exact expected label.
   - Two verdict events on different heads still give -3 after a new
     handover clears the standing verdict; non-verdict events between
     them do not affect the round.
   - The specified mixed legacy PR/result/current-head classification,
     same-head separate verdict events, and parser-classified non-verdict
     subjects. Historical subjects can be seeded by fixture store writes;
     do not call disabled legacy production verdict commands.
   - Research-review uses the same item-wide counter; non-review labels
     remain unchanged even when verdict history exists. Repeated reads
     do not change board refs or increment the label.
   - The existing history reader's cold Git fallback and warm-cache path
     produce the same label. A forced history-reader error causes the
     required refusal/no-output-file-write behavior; a non-review brief
     still works with that reader forced to fail.
   - Existing session-prefix behavior and the compatibility formatter
     remain unchanged.

   Keep every changed/new file at or below 500 lines. The explicit scope is
   `_work/brief.tl`, new `_work/brief_label.tl`, and new
   `_work/brief_label_test.tl`; the sibling files are the justified split
   from the original literal file list. No public cosmic module is added.
   New helper failures must use honest nullable two-slot return signatures;
   no existing ratchet baseline is expected to widen.

   Commit the real change before mutation testing. At minimum, force the
   review round to 1, verify the diff's -3 assertion fails, then restore
   exactly. Also demonstrate that filtering verdicts to the current head
   breaks the cross-head regression. Run focused checks/tests, coverage
   after the last test edit, and the repository's normal full gate.

## Non-goals

No changes to take/claim/verdict mutation semantics, handover validation,
history/event storage or parser grammar, cache schema, Git transport,
provider reads/writes, session identity derivation, or label reservation.
Do not revive PR-based review or add a result-only verdict workflow.
Build/research/refine/decompose labels and behavior remain unchanged.
Only the label brief review prints changes; the existing review-template
selection, body wording outside label documentation, and refusal precedence
before label resolution stay intact.
