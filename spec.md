## Evidence

When `--check types` fails, the agent-usability study (docs/agent-usability.md) found
the cost of a task scales with how far it strays from documented idioms, and that most
of the extra cycles went to "re-deriving undocumented semantics by trial and error".
The tree's answer is two things that do not talk to each other:

- `cosmic/_teal_hints.tl` (138 lines, 13 `Pattern` sites): hand-written message
  matchers, each ending in a generic pointer (`see cosmic --docs guide.gotchas`,
  `guide.checking`) that names the guide, never the section.
- `docs/guides/gotchas.md`: 11 `## <slug>` sections (`integer-vs-number`,
  `any-from-json-decode`, `nilable-arg`, `multi-return-capture`,
  `record-fields-dont-narrow`, ...), each explaining one trap in prose and a passing
  snippet, none carrying the checker's message for it in machine-readable form — the
  message appears in prose (`the got number, expected integer error carries the fix as a
  hint`) or not at all.

Measured 2026-09-05 at c39fc2f: a 22-line file with four classic traps (a record field
indexed through `| nil`, a `{integer}` indexed by a `number`, `ipairs` over
`json.decode`'s `any`, a one-value function captured into two locals):

```
$ o/bin/cosmic --check types bad.tl
bad.tl:14:9: error: cannot index object of type {integer} with number
bad.tl:17:16: error: attempting ipairs on something that's not an array: <any type>
bad.tl:17:29: error: unknown variable: k
bad.tl:21:10: error: assignment in declaration did not produce an initial value for variable 'b'
$ o/bin/cosmic --check types bad.tl 2>&1 | grep -c "^  hint"
1
```

One hint for four errors, and three of the four have a gotcha section written for them
(`integer-vs-number`, `any-from-json-decode`, `multi-return-capture`) that the output
never names.

Ranking guide sections by the message's words was measured as the fix and rejected:
an FTS5 table over the 31 sections of `gotchas`, `checking` and `lint` (bm25, slug
weighted 3x), each message's identifier-shaped words as an OR-query:

```
  cannot index object of type {integer} with number        -> checking#Type Annotations, gotchas#any-from-json-decode
  attempting ipairs on something that's not an array: <any -> gotchas#any-from-json-decode   (right)
  unknown variable: k                                      -> checking#Common Type Errors, lint#nil-declaration
  assignment in declaration did not produce an initial val -> lint#nil-declaration, lint#file-length
```

One of four right at rank 1: the message's vocabulary (`index`, `object`, `type`) is the
vocabulary of every section. A hint that names the wrong section costs more than no
hint. The signal that works is exact: the checker emits a closed set of message
shapes, and a section that documents a trap can carry the shape it explains.

## Change

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

## Non-goals

Ranked retrieval over guide bodies — measured at one in four above; if a later
measurement over a larger message corpus shows bm25 beating the symptom table for
messages no section claims, that is a new item with its numbers. Rewriting the hand
patterns. Hints for `--check lint` or runtime errors.
