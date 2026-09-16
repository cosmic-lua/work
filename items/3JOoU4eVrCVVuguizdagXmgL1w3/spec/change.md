Every builder brief carries a mutation-testing instruction of this shape:

    Mutation-test at least one guard the change adds or preserves: break what
    it guards, confirm the diff's own test catches it, restore it exactly.

For a change to GENERATED code that instruction cannot be followed as written,
and following it literally produces a green result that means nothing. The
obvious reading — break the file the test reads — is the one that cannot work,
because this repository's generators run before the graph on every verb that
touches it: the generator rewrites the mutated artifact from its untouched
source before any test sees the mutation.

Amend the instruction in `_work/brieftext.tl`'s builder template to say:

- mutate the SOURCE of a generated artifact, never the artifact itself;
- a mutation that leaves the tree green after a build that regenerates is
  INCONCLUSIVE, not a pass — the mutation never reached the test;
- name how to tell: if the file you edited is rewritten by the build, you
  mutated an output.

Keep it short. The templates are near the file cap and this is one clause,
not a section.
