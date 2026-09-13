`_work/{gitboard.tl,action.tl,item.tl,gitverbs.tl,gitverdict.tl,
session.tl,session_test.tl,gitverdict_test.tl,gitreview_test.tl}`,
prose and help strings only. No behaviour changes.

Each passage keeps what it says about CLAIMS and the review LEASE, and
drops what it says about an identity test withholding a verdict.

- `gitboard.tl:143` — `verdict --session` becomes the reviewing session
  and how it is derived, with no refusal promised.
- `gitboard.tl:110` — `next --session` keeps "skips work another session
  claimed", loses "and reviews of what this one built", and gains the
  review-claim skip that IS there.
- `action.tl` — the module header names `check`'s own lock (the review
  claim) as the second place a claim means something, `draw`'s rework
  paragraph gives the claim its real reason (it names who would
  ordinarily carry the rework on), and `reviewable` plus
  `ReviewPick.item` describe the walk the code performs.
- `item.tl:57-61` and `:292` — `builders` is described as the audit
  record of who has held the claim, readable in the committed file and
  the log, with its lack of readers stated rather than implied.
- `gitverbs.tl:186-189`, `:227-229` and `:241-242` — the three refusals
  keep their rules and lose "withhold a verdict from the item's
  builder", "review distance" and "disqualifies the earlier holder as
  reviewer" as their reasons.
- `gitverdict.tl:12-16` — `--session` is the audit half: nothing
  refuses on it, and the name rides in the commit subject.
- `session.tl:19-20` — an unnamed session collides with nobody, so no
  claim is withheld from it and its own moves record no holder.
- `session_test.tl:2` — matches the corrected `session.tl` header:
  distinct names are what make claims exclusive.
- `gitverdict_test.tl:114-116` and `gitreview_test.tl:89-90` — cite
  what is auditable and who may write a verdict, not a deleted rule.

Whether `gitboard show` should render `builders` is decided NO here:
rendering it is a behaviour change this item forbids, and the record is
already readable in the committed item file and the git log. The field
doc now says exactly that instead of claiming `show` prints it.

Second slice, after the sweep: `_work/{gitclaim_test.tl,gitview.tl,
converge_test.tl,action.tl,item.tl}`, same walls.

- `gitclaim_test.tl` — the header says what the file actually pins (the
  lease and what a handover must name), and the two `withhold a
  verdict` sentences give the claim its real job: it names the builder
  in the commit and the audit record, and it is a lock against
  concurrent writers.
- `gitview.tl:133-135` — the identity decides which work is WITHHELD
  and which CLAIMS are refused. Verdicts are not on that list.
- `converge_test.tl` — SAFETY drops the verdict clause it never
  asserted; `generate`'s two paragraphs keep the reason the asking
  session's own claims are drawn (a `do` claim is that session's to
  finish) and lose the verdict deadlock, which no longer exists.
- `action.tl:292-296` — the fall-through names the one thing
  `reviewable` steps over: another session's live review claim.
- `item.tl:57-62` — `builders` records the sessions a phase-crossing
  claim named, and says plainly that an in-place `--claim` takeover
  writes the claim without appending. `record_builder`'s doc
  (`:291-298`) is narrowed the same way.
