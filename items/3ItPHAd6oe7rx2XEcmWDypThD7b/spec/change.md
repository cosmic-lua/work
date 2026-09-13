1. **A symptom line per gotcha.** Each `## <slug>` section in `docs/guides/gotchas.md`
   opens with one fenced block:

   ````
   ```text
   error: got number, expected integer
   ```
   ````

   holding the message shape(s) the section explains, one per line, verbatim from
   the checker with positions and variable names elided as `...`. A `text` fence is
   what `_build/snippets_test.tl` already exempts from compilation (its header names
   the form), so no snippet gate changes. Sections whose trap is not a checker
   message (`colon-call`, `iterator-early-break`) carry none.
2. **Every symptom is real, gated.** `_build/gotchas_test.tl` (`--- reads:
   docs/guides/gotchas.md _build/testdata/gotchas`): for each section with a symptom
   block there is a fixture `_build/testdata/gotchas/<slug>.tl` that `--check types`
   refuses, and the refusal's message contains the symptom's text with `...` matching
   any run. A symptom the checker no longer emits fails here, so the guide cannot
   document a message that went away; a fixture that passes the checker fails too. Run
   the check in-process through `cosmic.teal.check_file`, the way the other `_build`
   tests avoid spawning.
3. **The hint reads the guide.** `cosmic/_teal_hints.tl`'s `hint_for_message` keeps
   its 13 hand patterns (they carry fixes, not just pointers) and gains a final fall
   through: `cosmic/_teal_symptoms.tl` (new, keeps `_teal_hints.tl` under the cap)
   loads `/zip/docs/guides/gotchas.md` once per process, parses the symptom blocks
   into `{slug, {shape}}`, and matches the message by plain `string.find` after
   turning `...` into `.-`. The hint line is
   `  hint: see cosmic --docs guide.gotchas — section <slug>`. A stripped artifact
   without guides yields no hint, as today. Existing hand patterns that end in the bare
   guide pointer are re-pointed at their section slug in the same edit.
4. `cosmic/_teal_symptoms_test.tl`: the four messages above each get a hint naming
   the right slug; a message no section claims gets none; a guide with a malformed
   symptom block is skipped, never a throw (library code returns, the file-length lint
   and `_build/gotchas_test.tl` are where malformed guides fail).
5. `docs/guides/lint.md` is unchanged: lint diagnostics already carry their rule name,
   which is the section slug.
