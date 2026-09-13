Add a sixth narrowing edit, `narrow-or-fallback`, to
`3p/tl/tl_patch.tl`: in tl's `or` handling, when the left operand's
resolved type is a union carrying nil and the right operand is not
`nil`, replace the left type with the union minus its nil member before
the branch chain that infers the expression's type.

Pin the behaviour with a test in `cosmic/teal_narrowing_test.tl`
alongside the existing narrowing tests: `local s: string = f() or ""`
where `f(): string | nil` must type-check, and the negative twin must
still refuse where it should.

Then open the upstream proposal to teal-language/tl carrying the
69-site measurement as evidence — it is soundness-neutral, needs no new
syntax and benefits every Teal user.
