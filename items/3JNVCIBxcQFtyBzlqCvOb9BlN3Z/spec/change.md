`--make coverage` does not narrow by path the way `--make test` does, and the
refusal does not say what it would accept.

Measured by a reviewer wanting one file's number:

    bin/cosmic --make coverage _work/snapshot_validate.tl
    make: nothing to do under: _work/snapshot_validate.tl
    coverage: FAIL (bad selection)

`--make test <path>` narrows by test-file path and is documented as doing so;
coverage's selection syntax, if one exists, is documented nowhere. The reviewer
fell back to a full ~6-minute instrumented suite.

Two parts, either of which closes it:

1. Make the refusal name the accepted selector, instead of `bad selection` —
   the stage knows what it globbed and can say so.
2. Document coverage's selection in the repository's AGENTS.md beside the
   existing `--make coverage` examples, stating plainly whether it narrows at
   all.

If coverage genuinely cannot narrow — an aggregate percentage needs every test
file that touches the module — then (2) is the whole fix and should say that,
because the failure currently reads as a caller mistake rather than a property
of the measurement.
