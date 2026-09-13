Two files. Insert the literal text below; change nothing else.

**1. `sys/help.md`** (75 lines, no cap concern). In the `Documentation:`
block, the line after `cosmic --docs guide.quickstart  your first
project, end to end`, insert:

      cosmic --docs guide.recipes  whole programs: which modules a CLI composes

Two spaces after `guide.recipes`, matching the `guide.testing` and
`guide.gotchas` lines directly below it, which already use two rather
than column alignment. The line is 74 columns.

**2. `docs/guides/quickstart.md`** (160 lines). Immediately after the
intro paragraph that ends `you do not have to.` (line 7) and before the
blank line preceding `## the layout` (line 9), insert a blank line and
this paragraph:

    this page is one project's skeleton. for whole programs — which
    `cosmic.*` modules a CLI, a file indexer or a TCP server composes,
    and in what order — read `cosmic --docs guide.recipes` alongside
    it.

That places the pointer on the first screen (rendered line ~9-12 of
161), which is what the eval evidence asks for.

**Leave the existing line 159 bullet in `where to go next` in place.**
It is correct there; the fix is an early pointer in addition to it, not
instead of it, and Acceptance 4 pins that both survive.
