Not a general clone detector: no near-miss or token-similarity matching,
no cross-tree analysis, no thresholds beyond the one size floor, no
committed baseline — the gate starts and stays at zero. Test files are
excluded from this slice: the same scan measured 8 duplicate groups of
test-helper boilerplate (16-line setup helpers ×4 among them), and
widening to them — whose real fix is shared fixtures — is a follow-up
once this gate has a false-positive record, as is `cosmic/**`. Constants
(`compiled_kinds`, `ENV_SWITCHES`) are out of scope: this keys on
function bodies, per the evidence. No change to `_cli/lint.tl`. No
change to the three historical sites, all resolved on `main` via #1185.
