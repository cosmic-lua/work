`_work/brieftext_bar_test.tl`'s `test_no_template_asks_for_pasted_measurement`
guards seven templates against the retired spec-bar language by asserting
three literal substrings: "measured with the command", "pasted output" and
"measured fact". A round-2 reviewer on «E0cK_TZFH» showed the guard does not
catch the phrasing that started that item: restoring BUILDER's original
"Re-run any measured commands the spec names" in a scratch copy leaves the
test green, because none of the three needles match "measured commands". That
regression is caught today only by a pre-existing, unrelated positive-content
test in `_work/brieftext_test.tl`, and only for BUILDER.

So the negative sweep has real teeth at exactly one site — REVIEW_SCRIPT,
which has no positive-content test of its own — and is redundant with
existing tests everywhere else. A guard that pins yesterday's exact wording
looks like a content check and is not one.

`_work/guidance_test.tl`'s sibling `test_guidance_does_not_ask_for_pasted_measurement`
takes the other shape: it checks the bare word "measured". The same reviewer
verified that word appears nowhere in any of the seven guarded templates at
`c72185131823c55b818423392915877ddc1034c9`, so a bare-word check would have
caught both the BUILDER mutation and the original REVIEW_SCRIPT regression,
with no false positive today.

Decide which shape the template guard should take, and make it that. Weigh
the case against the bare word honestly rather than assuming the reviewer's
suggestion: it forbids a word, permanently, in templates that may one day
have a legitimate use for it — RESEARCH in particular is about a deliverable
that genuinely does measure, and `POSTURE_RESEARCH` is already exempted for
that reason. A ban that later has to be argued around is its own cost. If you
keep a phrase list, say in the test why a list beats the word; if you take
the word, say why the exemption boundary is stable.

Either way the outcome should be a guard whose refusal a future reader can
predict without running it.

While there, a smaller thing the same review noticed: BUILDER, RESEARCH and
REFINE name `help bar` next to their short paraphrase of the rule, so a
reader can go find the authority. `REVIEW_SCRIPT`'s step 2 does not, and did
not before it was reworded either. Adding that cross-reference is a citation,
not a restructure.
