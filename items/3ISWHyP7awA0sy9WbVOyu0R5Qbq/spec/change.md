The measurement is complete and recorded in `## Result`. Nothing is
re-run and nothing is built. What this slice does now is verify that
the recorded evidence still describes the tree, then hand the findings
over as evidence. No file in the product tree is edited; the only
writes are to this item's own sidecar on the `board` branch.

1. **Re-read the two follow-ups the evidence selected** and confirm
   both are on the board and still open:

   ```
   cd o/board && o/bin/gitboard show 3ISlWFiS
   cd o/board && o/bin/gitboard show 3ISlY5Xl
   ```

   `3ISlWFiS` carries the base64 regression against
   whilp/cosmopolitan (the bisect range `07fc94a1c..354c17e08` and the
   six readings); `3ISlY5Xl` carries the release gate's one-A/A-pass
   hole. If either has been ended or re-scoped since, say so in a
   sentence appended to `## Result` under a bold lead — do not re-file
   it and do not re-measure.

2. **Confirm the tree still matches the two claims `## Evidence`
   rests on**, both of which are history and cannot drift, so this is
   a read, not a re-measurement:

   ```
   git log --oneline 07fc94a1c..354c17e08 -- tool/net/ljson.c \
     third_party/lua/luadecodejsondata.c net/http/encodebase64.c \
     net/http/decodebase64.c net/http/isbase64.c
   git log --oneline 07fc94a1c..354c17e08
   ```

   Run these from a whilp/cosmopolitan checkout (this repo's sibling;
   the session's own path for it is not fixed, so `cd` there first).
   The first must print nothing; the second must print five commits.
   If no whilp/cosmopolitan checkout is available in the session,
   record that it could not be re-read rather than asserting it — the
   claims are history and cannot have changed, so this is corroboration,
   not a gate.

3. **Append a dated verification note to `## Result`** — one bold-led
   paragraph naming what step 1 and step 2 returned, and the date —
   then replace the sidecar with `gitboard spec 3ISWHyP7 FILE`. Keep
   the heading exactly `## Result` and introduce no `###` heading
   inside it: `_work/spec.tl`'s `section_of` matches the heading text
   exactly and breaks at the next heading of any depth, so either
   would make the handover in step 4 refuse.

4. **Hand over as evidence**:

   ```
   cd o/board && o/bin/gitboard move 3ISWHyP7 check --evidence
   ```

   No PR is opened, on either repo. The reviewer reads `## Result`.
