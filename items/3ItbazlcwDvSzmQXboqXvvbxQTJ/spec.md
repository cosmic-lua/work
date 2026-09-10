## Change

Decompose the name-level surface and `cosmic --diff OLD` outcome into six
bounded children: token scanning, tree assembly, comparison/rendering, pinned
parser-schema preparation, archive loading, and CLI activation. The children
own implementation; this container owns only their order and shared walls.


Landing order is scanner → tree surface → comparison, while the parser-schema
child may land independently. Archive loading follows the tree surface. CLI
activation follows comparison, archive loading, and a release/pin carrying the
parser schema.

The current tree invalidates the old single-PR measurements:
`git show origin/main:cmd/cosmic/main.tl | wc -l` prints `244`, not 499;
`_cli/args.tl`, `_cli/parse.tl`, and `sys/help.md` are 174, 324, and 89 lines.
No dispatcher-line reclamation is required. `_cli.parse` is named in
`_build/make_boundary.tl`, so the option shape must land and ship before the
CLI reads it.

Every child has a file allowlist and a changed-line budget. A builder that
needs another subsystem returns to the orchestrator; it does not widen its
slice. Each landed child receives a fresh-context review of its exact commit.

## Non-goals

No implementation in this container. No surface baseline/ratchet, gone-name
wrapper tree, consumer scan, upgrade command, network access, or source rewrite.

