Make `test_friction_item_accepts_the_spec_the_caller_supplies` identify the
single newly created item by before/after ID difference, preserving its title
and spec assertions. Add no production behavior.

Prove the regression under controlled adverse same-second KSUID ordering,
restore controls exactly, and run the focused test plus the full gate.
