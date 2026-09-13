- **Do not edit `docs/guides/recipes.md`.** The eval finding is that the
  guide is not FOUND, not that its content is wrong; both agents who
  named it described it as sounding like the right page. Content changes
  are a separate item with separate evidence.
- **Do not touch `generate_welcome()` in `_cli/main_handlers.tl`.** The
  first-run banner is four lines whose job is to route to `--docs` and
  `--help`, and both of those name recipes after this change. Adding a
  fifth line is a different judgment about the banner.
- Do not reorder, retitle, or re-describe the other guides, in
  `sys/help.md`, `docs/guides/index.md`, or the quickstart's
  `where to go next` list.
- Do not add a new guide, a new `--docs` query form, or a new CLI flag.
- Do not change the `Documentation:` block's shape in `sys/help.md`
  beyond the one added line — `_cli/help.tl` reads `/zip/sys/help.md`
  and substitutes `{{recipe_verbs}}`, `{{make_verbs}}` and
  `{{env_vars}}`; none of those placeholders is in this block and none
  moves.
