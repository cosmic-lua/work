Make `cast-justify` accept a justification where the convention says to
put it: trailing the line carrying the `as` token, as well as the
expression's first line and the line above it. The AST node's extent is
available at the point the diagnostic is built, so the span to search is
the cast's own lines rather than a fixed one-line window.

Keep single-line casts, the allowlist path, and the diagnostic's anchor
line as they are — only which lines are searched for the justification
changes.

Add cases: a multi-line cast justified on its `as` line passes; one with
no justification anywhere still fails; and the existing single-line and
line-above forms keep passing.
