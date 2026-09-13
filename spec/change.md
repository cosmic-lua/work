Add a narrow, explicit opt-in that lets a caller swap `_work/api.tl`'s
`M.transport` from `no_transport` to a real one, WITHOUT `api.tl` itself
ever scanning the ambient environment. Concretely: a caller-supplied env var
name (e.g. `GITBOARD_PROVIDER_TOKEN_ENV=VARNAME`), read only by a new, small,
separately-named entry point — never by `api.tl`'s default load path, never
by any of the verbs `network_boundary_test.tl` already covers (`take`,
`gitworktree`, `storeinit`, `format`). The caller states exactly which env
var carries the token; gitboard never guesses `GITHUB_TOKEN`/`GH_TOKEN` on
its own.

Extend `_work/network_boundary_test.tl` (or add a sibling test) asserting:
the DEFAULT path (no activation requested) still refuses exactly as today —
every existing assertion in that file keeps passing unmodified — and the new
opt-in path, exercised with a fake env var pointing at a fake token in a
test, wires a real-shaped transport without touching real ambient discovery
in the process.
