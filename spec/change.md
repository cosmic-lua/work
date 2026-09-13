Add a `--print` flag to the `spec` verb that prints the item's current
raw spec text to stdout and exits, doing no write and requiring no
`FILE` argument:

- `_work/gitcommands.tl:84-87` (the `spec` verb's declared flags): add
  `{long = "print", help = "print ID's current spec text to stdout; no "
  .. "write, FILE omitted"}` alongside the existing `base`/`session`/
  `force`/`why` flags.
- `_work/gitboard.tl:317-326` (the `spec` dispatch branch): when
  `d.parsed.switches["print"]` is set, skip the `file == nil` refusal
  and call a new read-only entry point instead of `gitspec.cmd_spec`.
- `_work/gitspec.tl`: add `cmd_print(s: store.Store, id: string):
  integer` that loads the item (`store.load`, as `cmd_spec` already
  does at line 84) and, on success, writes `store.read_spec(s, id)` to
  stdout verbatim (no trailing verdict line, no `gate.verdict_line`
  wrapping — the whole point is byte-identical output usable as a
  file), returning the same refusal `cmd_spec` already produces via
  `gate.verdict_line("spec", false, lerr)` when the item doesn't
  resolve. Export it from the `gitspec` record and module table
  alongside `cmd_spec`.

This makes the safe-update sequence one line — `gitboard spec ID new.md
--base <(gitboard spec ID --print)` — without any caller needing to
know that items live under `refs/heads/items/<id>` at all.

Tests: `gitspec_test.tl` gains a case asserting `cmd_print`'s stdout for
a known item matches `store.read_spec`'s return exactly (no added
newline, no formatting); a case for an unresolvable ID asserting the
same refusal shape `cmd_spec` gives; a case piping `--print`'s output
straight into `--base` on a real (fixture) `spec` call, asserting the
compare-and-swap succeeds.
