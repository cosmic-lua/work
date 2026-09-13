Not auditing every existing `cosmic.ast` pattern in the tree for
whether it was ALSO silently failing to match local-declaration shapes
for the same reason — that is its own sweep, worth doing once this
fix lands and `--find`'s hit counts can be trusted to have moved.
