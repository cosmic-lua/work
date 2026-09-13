Two files, both `main` prose. No code.

**`skills/work/decompose.md`.** Under the ready bar, immediately after
the existing `**measured, not inferred.**` paragraph and its
`naming the command beside its output` follow-on, add one paragraph
that extends the same rule to behavioural facts. It must say, in the
file's existing voice and to its 90-column house style:

- what kind of fact this covers: what a verb prints, which branch a
  condition selects, what a report contains, where a rule fires, what a
  gate refuses. Reading the source to answer one of these is inference.
- the discipline: the spec carries the command AND the observed output
  it produced, not a description of what the code should do. A
  behavioural claim with no output pasted beside it has not been
  measured.
- the tell a refiner can apply: any spec sentence whose subject is a
  verb, a gate or a report and whose tense is present — "`next`
  surfaces …", "`show` reads …", "the restore fires exactly when …",
  "`verdict` refuses …" — is a prediction until a command has produced
  it.
- absence is behavioural too: a grep that returns nothing establishes
  that the PATTERN matched nothing, not that the thing is absent. Widen
  the pattern, or name what the narrow one could miss.
- the honest limit, stated plainly: nothing enforces this.
  `gitboard check` lints that the five sections are present and
  non-empty; it cannot tell an executed claim from a plausible one, and
  no static check can. This is a rule the refiner applies and the
  reviewer checks, and the command-with-output written beside the claim
  is its only artifact.

Then add one bullet to the `## anti-patterns` list — **behaviour by
reading** — naming the failure and citing D35's `N < f < 2r` as the
worked instance, in the same shape as the existing `acceptance by
vibes` bullet's citation of PR #1264.

**`skills/work/review.md`.** The bounce clause beginning `a bounce that
quotes a wrong or unmeasured tree-fact` names only tree-facts, which is
the same static-only framing. Widen that one sentence so an unmeasured
BEHAVIOURAL claim is the same named countermeasure, and so the fix it
demands is the command with its observed output. Do not restructure the
paragraph or touch the `--enable` sentences around it.

Measured now, from `/home/user/cosmic/o/wk-3IZ0nP5R`:

```
$ wc -l skills/work/decompose.md skills/work/review.md
  246 skills/work/decompose.md
  309 skills/work/review.md
  555 total
```

Both have ample headroom under the 500-line cap; the `.md` files are not
subject to it in any case.

The rule is asserted in exactly three places, inventoried with:

```
$ grep -rn "tree-fact\|measured, not inferred\|measured claim" skills/ docs/ AGENTS.md
skills/work/SKILL.md:341:   every measured claim carries its command (the ready bar demands
skills/work/review.md:290:a bounce that quotes a wrong or unmeasured tree-fact names its
skills/work/review.md:292:without measuring it — and the fix is a freshly measured claim, with
skills/work/decompose.md:175:**measured, not inferred.** every tree-fact the spec relies on (a
```

The third, `SKILL.md`'s pull-time re-measure step, needs no edit: it
says every measured claim carries its command and the claiming session
re-runs it, which a behavioural claim's command satisfies unchanged.
