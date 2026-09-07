## Evidence

`«0LDT_eyE3»`'s spec asked for `_build/nil_returns_test.tl` to become a
casts-style AST-pattern allowlist over "the 7 flow positions" `docs/design/nil-flow.md`
documents (argument, operand, return, assignment, table-field, index-key, "the tail"),
claiming this is "exactly what an AST pattern selects" and that the walk is
"`_build/nil_returns.tl`'s existing site finder rewritten over `cosmic.ast`".

Both premises are false against the current tree, confirmed twice — once by an
orchestrator pre-check before the item was pulled, once independently by the builder
agent pulled to build it (which stopped without writing any code, per its brief's own
"spec turns out wrong" exit):

1. **`nil-flow.md`'s 358-site census is not derivable from syntax.** Its own Method
   section (`docs/design/nil-flow.md:29-33`) states it: "The census comes from a
   throwaway strict checker, built inside `o/` and deleted before this change was
   gated." The two hinges it patches into `tl`'s real `TypeChecker`
   (`subtype_relations`'s nil-admits-everything rule, and `unite()`'s nil-dropping
   ahead of `binop_types`) require genuine type inference: whether a name is nilable
   depends on a callee's declared return type (often in another file), and on whether
   a preceding guard was `return` (narrows) or `break` (does not) — both properties
   `cosmic.ast` pattern matching cannot see, because it matches syntax shape, not
   resolved types. The doc's own worked examples confirm this directly:
   `cosmic/fs/tree.tl:28`'s `entry` is nilable only because `h:read()`'s cross-module
   return type is; `_tool/testrun_test.tl:21`'s `(out or "nil")` is flagged only
   because of tl's specific `or`-typing behavior (`nil-flow.md`'s Mechanisms section,
   "teach `or` to drop nil: 69 sites").
2. **`cosmic.ast` has no type-resolution capability to build this on.** No hits for
   `infer|TypeChecker|resolve_type|declared_type` across `cosmic/ast/*.tl`,
   `_cli/*.tl`, `_tool/*.tl`, `_build/*.tl`. The casts precedent the spec cites
   (`cosmic/ast/match.tl`, `_build/casts_kinds.tl`) works only because a cast's own
   syntax (`expr as Type`) carries its target type literally in the text being
   matched — a nil-flow site carries no such marker.
3. **`_build/nil_returns.tl` is not "the existing site finder" for this census at
   all.** It implements a different, narrower, unrelated thing: `_cli.nilreturn`'s
   lexer counts literal `return nil` text inside a function whose declared slot 1
   cannot hold nil — one subset of one of the 9 documented classes (`return`), not a
   walk over any of the other 6. Nothing in the tree reads
   `docs/design/nil-flow-sites.tsv` today (`grep -rl "nil-flow-sites.tsv"` outside
   `docs/` is empty) — it is inert prose evidence, not a maintained artifact with a
   live reader to rewrite.

Forcing a syntactic proxy through anyway (e.g. flagging only sites with an explicit
`T | nil` local annotation at point of use) would silently redefine what "nil-flow
site" means, produce a materially smaller and different set than the tsv being
retired, and violate the spec's own Non-goals ("no site is reclassified").

## Change

None — this item is a question, not a build. Its resolution is a decision about
what, if anything, this repo commits to maintaining for the nil-flow census, made
with the fact above in hand. Candidate shapes worth naming, not committing to:

- Leave `nil-flow.md` and `nil-flow-sites.tsv` exactly as documented today — a
  point-in-time snapshot re-derived by hand (rebuilding the throwaway strict
  checker) whenever someone wants a fresh count, never gated. This is already the
  status quo and needs no PR.
- Recognize `«0LDT_eyE3»`'s premise (casts-style AST allowlist) does not transfer to
  nil-flow, and that the parent outcome's "no committed floor remains" goal is
  already met for nil-flow in the one sense that IS true: `nil-flow-sites.tsv` was
  never a gated floor (nothing reads it), so there is nothing to un-gate.
- Separately: `_build/nil_returns_test.tl`/`_build/nil_returns_baseline.tl` (the
  return-nil-under-non-nil-signature ratchet `_cli.nilreturn` actually powers) is a
  real, live, working floor — but it has exactly one class, not seven, so the
  "kinds allowlist" shape casts moved to does not obviously apply to it either; if
  it is worth simplifying, that is a distinct question from this item's premise and
  would need its own spec, not a relabeling of this one.

## Non-goals

Not proposing an answer here for which candidate (if any) to pursue — that decision,
and any resulting spec, belongs to whoever picks this up, informed by the Evidence
above.

## Access

cosmic-lua/cosmic, read only; no repository access needed to decide.
