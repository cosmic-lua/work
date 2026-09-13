- **Do not repoint any citation to a corrected line number, and do not
  convert any of the nine sites to the fenced form.** Both re-create the
  defect against PR #1490, proved above. `_perf/run.tl` is the file under
  #1490; the treatment for `docs/design/make/resolution.md:231` is the
  symbol name, and that is why this item carries no `blocked_by`.
- **Do not touch `docs/design/nil-flow.md`.** It is the tree's one
  `Measured against` snapshot; its 16 matching lines are exempt by design
  and must still be 16 after.
- **Do not change `_cli/lint.tl`.** The `.md` wiring already exists at
  `_cli/lint.tl:375-379`, and the file is 419 lines against the 500 cap.
- **Do not widen the recognizer.** No cross-line code-span pairing, no
  existence check on bare backticked paths, no sweep for `path:line`
  outside a backticked span — the last would flag the quoted runtime
  traceback at `docs/agent-usability.md:132`, which is not a tree
  citation. The wrapped-span blind spot is filed separately.
- **Do not rewrite the substance of the nine sentences.** The prose in
  `docs/agent-usability.md` and `docs/decisions/d28-shape-combinators.md`
  describes a tree that has since moved; correcting that is other work.
  Remove the line span, name the symbol, stop.
- **Do not add a decision record**, and do not change the `Measured
  against` snapshot mechanism or the `doc-citation` rule name — the rule
  name is what the gate prints and what the guide indexes.
- **Do not tag any new fence `teal`.** `_build/snippets_test.tl` compiles
  every `teal` fence in the tree at full strictness and holds it to the
  formatter; the guide's new examples are markdown, so they stay untagged.
