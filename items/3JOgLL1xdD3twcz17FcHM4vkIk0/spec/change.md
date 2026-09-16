Add a rule to the spec bar (`gitboard help bar`, and the check `new`/`show`
run against a spec): a `## Change` may not leave an unbounded quantifier or an
unsourced existence claim for the builder to resolve.

Two shapes, both of which a builder must go and settle empirically before it
can make the first edit:

1. **An unbounded quantifier.** "every spawned agent", "all the callers",
   "each template" — where the spec does not name the set. The bar should
   require the set be named, or the quantifier be scoped to something the
   builder can enumerate from the spec alone.

2. **An unsourced existence claim.** "the tool already knows X", "this is
   already recorded", "the caller has it" — where the spec does not name the
   field, file, or function that holds X. The bar should require the citation.

These are the same defect: the spec asserts something is determinate without
saying where the determination lives, so the builder does the research the
spec bar exists to have already done.

Both are cheap to check mechanically enough to be useful — a spec whose Change
contains "every"/"all"/"each" or "already knows"/"already records" without a
path-like or field-like token nearby is at least worth flagging — but the rule
is worth stating in `help bar` even if the check stays advisory.
