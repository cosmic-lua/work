New module `_work/brieftext_friction.tl` (well under 40 lines) holding
one string, `ASK`: the paragraph from `skills/work/friction.md`'s
"what the agent reports" block — a `## Friction` section of at most
five entries, each with the goal, what happened instead with how long
and how many tool calls, what made the difference, and what would
have prevented it; an empty section is a real answer. `_work/brief.tl`
appends `ASK` after the "Final report" section of every kind it emits
(builder, research, review, refine, decompose), unconditionally: a
pass not collecting friction ignores the section at no cost, and one
that is never has to remember it. `_work/brieftext.tl` is untouched,
so this lands without the template split.

`_work/brief_test.tl`: one `find` per kind pins `ASK`'s first
sentence. `skills/work/friction.md` (a follow-up PR on main, after
this ships in a release): delete the sentence that says to append the
paragraph by hand and say the brief carries it.
