Does NOT auto-fix inside `--make ci`. A gate that rewrites its own input is no
longer a gate, and formatting churn would land in a diff without anyone
choosing it. The fix belongs before the gate, run deliberately.

Does not change the formatter's opinions, only how a caller applies them in
bulk. `cosmic --fix` already accepts several paths in one call (verified), so
this is about the stage knowing its own failing set, not about the fixer.
