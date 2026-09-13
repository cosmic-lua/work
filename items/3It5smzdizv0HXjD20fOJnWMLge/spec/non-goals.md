Everything the parent's Non-goals already state; in particular, do not
duplicate `gitready.ready_problems`'s spec-bar logic into a second,
cache-specific implementation — it already runs correctly, unchanged,
against whatever `{Item}` list its caller supplies.
