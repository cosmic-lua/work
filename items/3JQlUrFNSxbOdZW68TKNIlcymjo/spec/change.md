Two brief sentences that cost every builder and reviewer a repeat of work the
pass already does:

1. Builder step 3 in `_work/brieftext.tl` tells the builder to run `--make
   coverage` after its last test edit AND to run the full gate once before the
   push; the full gate already runs the coverage stage, so builders run both.
   Replace the coverage sentence with one saying the full gate runs coverage,
   so run the gate once after the last test edit and never a separate
   coverage stage; keep the note that a new test moves a coverage row.
2. The mutation paragraph of the diff posture in `_work/brieftext_review.tl`
   gets the same generated-code clause the builder template already carries:
   mutate the SOURCE of a generated artifact, never the artifact; a green
   regenerating build is inconclusive; the generator's first refusal is not
   a catch, rerun until a named assertion fails.

Regenerate the committed renderers under `_work/brieftmpl/`. Pin both
sentences in `_work/brieftext_test.tl` the way that file pins the builder's
generated-code clause today.
