Running a throwaway script through `bin/cosmic` from the cosmic repository root
triggers a full `--make build` of the tree before the script runs.

Measured: a one-off `bin/cosmic /dev/stdin <<'EOF' … EOF` used to patch a file,
run from `/home/user/cosmic`, emitted the whole generate/compile sequence —
`generate _types/types_gen.tl`, ~90 `compile o/cosmic/…` lines,
`build: PASS (711 files, 1 binary)` — before executing three lines of Lua. Run
from a neutral directory the same script starts immediately.

This is convergence doing its job: at a make root, the tool builds and re-execs
into what it built. For a `--make` verb that is exactly right. For a bare
script path it is a surprise, and an expensive one when the tree is cold.

Skip convergence when the command is a bare script path rather than a `--make`
verb: a script is not a gate and makes no statement about the toolchain, so it
does not need the tree's own build. `_make/converge.tl` decides this
(`grep -n "converge" _cli/*.tl`), and the dispatcher already distinguishes a
script invocation from a verb.

If the current behaviour is deliberate — a script at a make root should see the
tree's own modules — then say so in AGENTS.md beside the `cosmic -e` /
`/dev/stdin` guidance, because the cost is invisible until it happens.
