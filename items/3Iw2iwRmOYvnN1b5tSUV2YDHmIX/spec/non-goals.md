Not re-litigating `HlNE_YWL2`'s own design (require explicit repo/base
at attach time vs. resolve-by-inheritance) — that decision belongs to
that item, already under refinement. Worth checking, once `HlNE_YWL2`
lands, that its own test suite covers an item that gained its parent
via `attach` (the exact path this repro took), not only `new --parent`
— its own Evidence section describes both paths but this repro is a
concrete `attach` case to check against once it ships.
