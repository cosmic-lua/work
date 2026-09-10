## Evidence

`gitboard done ID --landed SHA` (and `claim`, without `--execute`)
prints lines that read as already executed:

```
prepared refs/gitboard/prepared/<txn>
publish: git push --atomic --force-with-lease=... origin ...
refresh refs: git fetch --atomic --prune origin ...
```

Nothing has actually pushed at this point. A separate
`gitboard publish <TXN> --execute` call is required to run that exact
push, and then a `gitboard refresh --execute` to confirm it. `done
--help` and `claim --help` never mention `publish` at all; only
`refresh --help` documents its own two-phase (`--execute` runs the
fetch; without it, the command "prints the exact fetch command but
does not run it").

Reproduced live on 2026-09-10: after two `gitboard done ID --landed
SHA --force` calls appeared to succeed, `gitboard show ID` still
reported `state: accepted` (not `completed`), and `git ls-remote`
against the board's own remote showed the item refs unchanged from
before the `done` calls. Several minutes were spent reading raw
remote refs with `git ls-remote` before noticing `publish` in
`gitboard`'s own top-level verb list and realizing every prior mutating
call (`claim`, `done`, `drop`, `new`) in this session had silently only
*prepared* a transaction rather than pushing it — most had happened to
also pass `--execute`, which pushes but still requires the separate
`refresh --execute` to confirm, so the confusion was specific to
verbs/flag-combinations that stop at "prepared."

## Non-goals

Not a request to remove the prepare/publish/refresh split — the
two-step confirm protects against a lost race. This is about `done`'s
(and other mutating verbs') own help text and printed output not
saying a second command is needed to actually take effect.
