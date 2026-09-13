Correct `AGENTS.md`'s example so it does not name a build output. Say
what the lint enforces: a declared path must be a SOURCE the cold tree
carries — a committed fixture, a script, a doc — and a generated artifact
under `o/` is declared by its sources instead, or derived in-process.

The two remaining examples are both correct and can stay. Replace only
the third, and add the one-line reason (it does not exist on a cold
tree), so a reader understands the rule rather than memorising a list.
