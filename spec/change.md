1. **`_work/gitverdict.tl`** — a `KIND_ALIASES` map
   (`request-changes` and `rework` → `request changes`), applied
   before the `VERDICT_MOVES` lookup; the unknown-kind refusal
   enumerates the vocabulary with each kind's consequence
   ("accept, 'request changes' (to do, claim kept; request-changes
   and rework are aliases) and reject (to backlog, commitment
   spent)"). The verdict is RECORDED under the canonical spelling,
   so `is_rework` and every reader of `item.verdict` see one value.
2. **`_work/gitverdict_test.tl`** — one test: an unknown kind is
   refused; the hyphenated spelling moves the item to `do` with the
   builder's claim kept and the verdict recorded as
   `request changes`.
3. **Rejected, recorded here**: a confirmation step on `reject`.
   Sessions are non-interactive, so a confirm degrades to a flag
   nobody reads; the real protection is that the fall-through path to
   reject no longer exists (the aliases catch the plausible
   spellings, and the refusal teaches the rest), while reject keeps
   its existing deliberateness cost (`--enable` is already
   mandatory).
