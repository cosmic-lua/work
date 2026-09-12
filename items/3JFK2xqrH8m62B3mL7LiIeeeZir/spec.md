## Evidence

`AGENTS.md` and the `reads-declaration` lint disagree about what a
`--- reads:` header may name, and the document is the one an agent reads
first.

`AGENTS.md:422-424` gives three examples of a file the graph cannot see:

    a script copied with `fs.copy`, a fixture under `testdata/`, a
    generated index under `o/`

`_cli/reads_lint.tl:118-129` refuses the third:

    if is_o_path(token) and names_build_output(token) then
      ... "`reads: %s` names a build output, which does not exist on a
      cold tree; derive it in-process from the tree (the generator's own
      module) or declare the SOURCES it is built from"

The lint's reasoning is sound — a build output does not exist on a cold
tree, so declaring it cannot key anything. The doc's example is
therefore not merely under-specified, it is the exact case the lint
exists to reject.

Hit while building `«uOsC_KV6H»`: a builder tried to declare a marker the
generator writes under `o/`, following the AGENTS.md sentence, and lost
roughly ten minutes discovering the rule by tripping it. The lint message
is good and names both alternatives; nothing pointed at it beforehand.

## Change

Correct `AGENTS.md`'s example so it does not name a build output. Say
what the lint enforces: a declared path must be a SOURCE the cold tree
carries — a committed fixture, a script, a doc — and a generated artifact
under `o/` is declared by its sources instead, or derived in-process.

The two remaining examples are both correct and can stay. Replace only
the third, and add the one-line reason (it does not exist on a cold
tree), so a reader understands the rule rather than memorising a list.

## Non-goals

Not changing the lint, its message, or which paths it rejects — the rule
is right. Not changing the `--- reads:` syntax or the runner's recording
behaviour. Not auditing existing `--- reads:` declarations for
violations; the lint already does that on every run.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.
