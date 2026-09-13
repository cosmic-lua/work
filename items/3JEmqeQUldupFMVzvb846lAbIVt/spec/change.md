In `_work/ghland.tl`'s arming path: after reading the request for its node
id, compare `p.head_sha` against the judged head. Arm auto-merge only when
they agree; when they disagree, land nothing and report it the same way a
409 is now reported — the reviewed commit is not what would land, so the
caller decides by hand.

Add a case: a 405 refusal whose subsequent request read shows a head other
than the judged one sends no arming mutation and reports the mismatch. Keep
the existing 405-with-matching-head case arming as it does today.
