## Evidence

At `6e91fabe2e2c2c6bde2ff5a54d123e48cc702a26`, `_cli/rewrite.tl` routes `--rewrite` without `--apply` to the find path. It reports matching syntax, but does not exercise the proposed replacement or return the refusal decisions made by apply. `cosmic.ast.rewrite(source, name, pattern, replacement)` already computes a rewritten result and refusals without writing files.

Board consumer `«Gdfd_MjoQ»` / `3IybIczIrM71jPKb80XGdfdMjoQ` requires evidence that a proposed sweep is actually applicable. Its motivating case found 12 matches, but many were excluded fixtures or matches inside long strings; a count alone did not prove the operation could be applied.

## Change

Expose an explicit non-writing preview for a pattern plus replacement across selected paths. Reuse the same file selection, parsing, replacement validation, and refusal logic as apply, with the write as the final optional step. Keep the current find-only invocation compatible; choose and document an unambiguous preview spelling.

Report proposed edits with source locations and replacement content (or a diff), per-site/file refusals, and separate counts for matches, proposed edits, and refusals. Never label previewed edits as actually applied. The preview must validate the replacement, not merely rerun a pattern search.

## Acceptance

- For identical source bytes and arguments, preview and apply select the same files and produce the same planned edits and refusals; applying a successful preview produces exactly its predicted bytes.
- Preview changes no source bytes or mtimes, including when a later file fails.
- Fixtures cover valid changes, no matches, malformed replacements, comment-loss refusals, and excluded project paths; matching text inside string literals is not mistaken for executable syntax.
- Preserve and document existing partial-refusal behavior rather than silently introducing transactional apply semantics. Define preview exit statuses for clean, no-op, refused, and invalid-input results.
- Public help and examples show how a spec author captures preview evidence before authorizing a sweep.

## Consumer policy

The user approved requiring dry-run evidence for commands that already exist; when work introduces the command itself, accept a failing behavioral reproduction and require preview evidence once the capability exists. Do not make a new command's implementation depend on running that unavailable command first.

## Non-goals

No second rewrite engine, GitBoard-specific logic in Cosmic, automatic application, or generalized AST type/data-flow analysis.

## Access

cosmic-lua/cosmic, read and write on a branch. The GitBoard consumer is context only; changes to its policy remain in its existing item.
