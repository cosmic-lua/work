Not changing the 500-line cap or `--check lint`, which stay exactly as they
are and are the reason this is safe to remove. Not changing how a spec's
prose NAMES files — a spec may still point a builder at a file or a
function, as a hint. This removes machine extraction and validation of those
hints, not the hints.
