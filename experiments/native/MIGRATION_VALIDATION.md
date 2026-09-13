# Full-board migration validation — 2026-09-13

This was an offline audit of an independent `git clone --mirror --no-hardlinks`
copy of the fetched cosmic-lua/work repository. No source-board refs, pending
draft, or remote destination were changed. Native activation was simulated
only inside the isolated audit copy; this does not attest a live freeze or
perform a cutover.

## Frozen snapshot

- Snapshot time: `2026-09-13T21:50:11Z` (`1789336211`).
- Source prefix: `refs/remotes/origin/`.
- Complete source set: **1,946 refs** — 707 items, 723 ended items,
  515 claim batches, and `board/seq`. The format marker is separate.
- SHA-256 of `_work.singlehead_literal.encode(checkpoint.sources)`:
  `9501941dfc0df4435b497634dc16c3c66fc1bf537295a97c3ab362dad4c8decd`.
- Candidate state:
  `0d21e219baef6573dca60f8dd50eea8b1ed9dce7`.

## Results

| Check | Observed result |
| --- | --- |
| Final items | 1,430; every source item retained |
| Source commits / migration marks | 13,760 / 13,760; exact one-to-one SHA mapping |
| Item-event associations | 13,761; every association present in the native path-attributed history |
| Commit identities and messages | Every author, committer, raw date/timezone, and message byte preserved |
| Final metadata | Every byte matched after removing `claim_batch` and applying eligible board-evidence remaps |
| Other payloads | All 2,246 blobs and modes matched, including 2,181 spec blobs |
| Materialized logs | 2,060 empty attribution files; zero visible notes; exact legacy prose semantics |
| Recorded leases | All 120 matched acquisition ID, holder, acquisition/renewal/expiry times, and product base, including expired records |
| Persisted marks | The canonical tree literal exactly matched the checkpoint map |
| Native canonical audit | Zero problems |
| Full native `gitboard fsck` | Cache agrees with refs; `ok (1430 items)`; exit 0 |

The full board exposed one shared source commit,
`e83f3c1ac37c55ba165f68c100e580ebbcfd0238`, in two different ended-item
histories. The migration now replays that commit once while grafting both
item paths, preserving a single unambiguous old-SHA mapping and both history
attributions. A regression test and semantic mutant cover that case.

A full frozen-checkpoint restart also exercised the boundary between the
replay tip and the final marks/evidence commit. Replay now uses a fresh private
attempt ref and promotes the complete candidate with a local compare-and-swap;
an interrupted attempt leaves the prior completed candidate readable. A
separate regression covers failure, retry, and temporary-ref cleanup while a
detached audit worktree still names the completed candidate.

## Timings and restart

Wall-clock measurements on this audit host, rounded to seconds:

| Operation | Seconds |
| --- | ---: |
| Complete replay | 187 |
| Unchanged-checkpoint restart (`identical`) | 1 |
| Full replay from a frozen checkpoint, completed candidate retained | 184 |
| Payload, history, and canonical audit | 37 |
| Full native fsck, including cache comparison | 15 |

The corrected v2 full frozen-checkpoint replay regenerated the same candidate
SHA and all 13,760 marks. These are observed run times, not a throughput guarantee. Thirteen
migration checks passed in a fresh isolated direct harness; all twelve semantic
mutants were killed, including the previously surviving pre-snapshot guard. Strict type, format, and lint checks passed for the
changed migration files.

## Existing evidence caveat

None of the snapshot's current `result`, `verdict_head`, or `landed_head`
values names a replayed source commit. The **678 existing values** therefore
remain byte-identical: 19 result values, 550 verdict heads, and 109 landed
heads. In the audit copy, 10 resolve to blobs, 191 to commits outside the
frozen source history, and 477 are unavailable; nine values are not 40
characters long. No value is reachable as a commit from the frozen source
ref set. This audit does not infer whether an unavailable value belongs to
another repository or to older rewritten history, and does not silently
replace it. Synthetic migration tests separately verify eligible result
remapping and claim-bridge attribution.

## Review correction: note semantics and executable freeze proof

The original audit compared the complete bytes after each commit subject.
That comparison preserved bytes but used the wrong semantics for user notes:
the 2,060 entries contained only `Op: migrate` or `Op: import` trailers.
The v2 replay now applies the same prose parser as legacy log reads. It keeps
an empty attribution file for each administrative event, preserving every
historical item event and tip while exposing no fabricated note. Older v1
checkpoints refuse reuse and require a fresh replay path.

The corrected audit retained the same frozen source digest. All 2,060 physical
attribution files are empty, all 13,761 item-event associations remain present,
and visible notes total zero. A separate fixture verifies two exact prose
bodies, paragraph preservation, trailer removal, empty administrative markers,
and the final administrative event's tip attribution.

Production `plan --freeze-ruleset ID` explicitly uses authenticated `gh api`
with `--hostname github.com`; it reads ruleset configuration before and after
a fresh private source fetch. It requires an active repository branch ruleset,
exactly the four legacy ref patterns, no exclusions or bypass actors, and
creation/update/deletion restrictions with fetch-and-merge bypass disabled.
Missing `bypass_actors` refuses because GitHub omits that field without ruleset
write access. Server observation times and the unchanged ruleset digest bracket
the fetch; the literal checkpoint binds those observations to the exact push
destination and full source-map digest. `publish --execute` fetches and verifies
that same live policy again and rechecks the complete destination source set
before atomic activation. Plain plans and caller-supplied booleans cannot take
this production path. The default publication command only renders a plan.

The provider was validated with mocked HTTP responses; `gh` is unavailable in
this audit environment, and no live ruleset was queried or changed. Public API
contracts used:
[GitHub ruleset response and access rules](https://docs.github.com/en/rest/repos/rules#get-a-repository-ruleset)
and [GitHub CLI API headers and hostname selection](https://cli.github.com/manual/gh_api).
