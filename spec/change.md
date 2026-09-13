1. `cosmic/headings.tl` (or wherever fits): port `sections`
   near-verbatim as a generic markdown heading-section scanner, and
   `ready_gaps` generalized to `required_sections(body, names)` (or
   similar) taking the required heading list as an explicit argument
   rather than a module constant.
2. Tests: port the existing coverage over heading levels, thematic
   breaks, and hollow-section detection.
3. `cosmic --docs` entry and module description, with an example use
   case (a doc linter, a PR-template checker).
