## Evidence

Builder «g0eF_1vae» (2026-09-06, cosmic-lua/work#44) reported: its first
mutation appended a character to a substring-matched needle, the test
stayed green (a `find(needle, 1, true)` still matches a string that
contains the original as a prefix), and it needed a second round —
2 extra tool calls — to mutate to unrelated text. The builder brief's
mutation step (`_work/brieftext.tl`, step 5: "break what it guards,
confirm the diff's own test catches it, restore it exactly") does not
say what a real break is. The same false negative applies to every
substring, prefix, or pattern assertion.

## Change

`_work/brieftext.tl`, builder step 5 (and the review template's
mutation sentence in `_work/brieftext_review.tl:~94`, which repeats
it): add one sentence — "A real break changes the outcome the test
reads, never just the text around it: replace a matched needle with
unrelated text rather than extending it, flip a boolean rather than
renaming it, and if the test stays green the guard is decoration."
`_work/brieftext_test.tl`: the existing template-content cases gain
one asserting both templates carry "replace a matched needle".

## Non-goals

No change to the numbered structure or any other step.
