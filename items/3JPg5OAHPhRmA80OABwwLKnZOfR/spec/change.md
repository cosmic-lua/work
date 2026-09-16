`--session` names two different things across sibling verbs, with no hint at
the point of use:

- on `claim`, `renew`, `drop`, `take`, `verdict`, `done`, `worktree` and
  `handoff` it is the minted claim identity;
- on `brief` it is the receipt caller, and passing a claim session there is
  refused with `--session requires a builder --receipt`.

`brief` already finds the item's claim session itself and names it on its own
verdict line, so the flag is not needed there for the common case.

Either accept a claim session on `brief` and ignore it when it matches the
item's recorded one, or refuse with a message that says what the flag means
here rather than what is missing:

    gitboard-brief: REFUSED: --session on brief names the receipt caller, not
      the claim; the claim's session is found automatically — drop the flag,
      or pass --receipt with it
