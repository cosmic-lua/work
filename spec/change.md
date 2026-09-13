Board-tooling change on the `board` branch of cosmic-lua/cosmic, as a
PR against base `board`:

1. `_work/item.tl`, `problems(it)`: report `is_held` on an item whose
   `resolution` is non-empty, beside the existing parented-item guard.
2. `_work/githold_test.tl`: the test that hand-saves a done-and-held
   root to exercise `cmd_unhold`'s refusal must bypass the validator
   deliberately (write the file directly, the way the store test
   fixtures do) or assert the refusal from a state `problems` accepts;
   add one case that `item.problems` reports the done-and-held shape.
