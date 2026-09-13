Give `head_moved` a docstring clause stating what its `judged` argument is
expected to be — a canonical full sha — and that a caller holding a
possibly-abbreviated sha wants `head_refusal`'s prefix match instead. State
the empty-judged-head behaviour explicitly, so a reader sees that passing
`""` disables the check rather than having to derive it from the
short-circuit.

In `_work/ghland.tl`'s arming guard, render a headless read as something
that reads as a sentence — naming that the request reported no head, rather
than interpolating an empty string where a sha belongs.
