## Change

Ready when: `cosmic --diff` and the gone tree are on main (sibling
items; `ls cosmic/_gone/ _cli/upgrade.tl`).

`cosmic --upgrade [OLD]` reports, for one project, every use of a
public name that left or was retyped between OLD and the running
binary, each with its wrapper's `gone` line, then says what to run.
It touches no network and rewrites no source; `apply` is the sibling
item. The trust-root script gains the one line that fetches a new
release, so the whole upgrade is two commands.

**Flag.** `_cli/args.tl`: `{long = "upgrade", arg = "OLD",
arg_optional = true, help = "report what this release breaks in the
project, against OLD"}`. Dispatch line in `cmd/cosmic/main.tl` beside
`--diff`'s (the `--diff` item reclaimed the room). `sys/help.md`
entry after `--diff`.

**OLD** defaults to `o/bootstrap/cosmic.ape` under the project root —
the pristine previous release `bin/cosmic` keeps (`bin/cosmic:24`,
"the pristine download too, beside it as `<bootstrap>.ape`"), so a
pinned project needs no argument. No such file and no argument →
`upgrade: no previous release at o/bootstrap/cosmic.ape; pass the old
binary: cosmic --upgrade path/to/old-cosmic`, exit 2.

**Scan**, in `_cli/upgrade.tl` (created by the `--diff` item):

1. `deltas = surface.diff(surface_of(OLD), surface_of(self))`,
   keeping `removed`, `retyped`, `module-removed`.
2. Read the running binary's `cosmic/_gone/**.tl` from `/zip/.tl/`
   and lex them: for each wrapper (function name, its `gone` doc
   line) and each `-- gone` line, index by surface key.
3. Walk the project (`_make`'s model — the same file set `--make
   check` sees, so `.cosmicignore` and `o/` are honored) and for each
   `.tl` source: read its `local <alias> = require("cosmic.<m>")`
   bindings; lex; report every `alias . name` token pair where
   `cosmic.<m>.*.name` is a removed or retyped function, every
   `require("cosmic.<m>")` of a removed module, and, for a `-- gone`
   record-field key, every `name =` token pair inside a table
   constructor that is an argument to a call on that alias. A retyped
   use already wrapped in `check.must(` or `assert(` is not reported
   (the retype has been handled).

**Report**, one line per use, then a verdict line and the next step:

```
notes/render.tl:10  cosmic.string.truncate → ellipsize (gone 2026-09-06): renamed; same arguments, same result
notes/render.tl:15  cosmic.string.shell_quote retyped (gone 2026-09-06): same name, new type — nil when s holds a NUL byte ...
notes/store.tl:6    cosmic.uuid → cosmic.rand (gone 2026-09-06): the module folded into cosmic.rand ...
notes/store.tl:45   cosmic.json.Options.pretty (gone 2026-09-06): a non-nil indent means pretty; {pretty = true} is {indent = "  "}
upgrade: 5 uses of 4 names that left (surface: 5 removed or retyped, 2 added; `cosmic --diff OLD` lists them)
next: cosmic --upgrade OLD apply   rewrites the 4 with a wrapper; then cosmic --make ci
```

A name that left with no wrapper and no `-- gone` line (an older
release than the gate) prints `(no wrapper shipped; see cosmic --docs
cosmic.<m>)`. Exit 1 when any use is reported, 0 when none
(`upgrade: nothing to change; run cosmic --make ci`), 2 on a usage
error. The verdict line is the last line, per `guide.make`'s
machine-readable output rule.

**Pin.** When `bin/cosmic.pin` exists at the root and the running
binary's stamp (`require("cosmic._version")`, the tag `release.yml`
writes; a tree build reads `unknown`) is a release tag, rewrite the
pin's two lines: `url =
https://github.com/cosmic-lua/cosmic/releases/download/<tag>/cosmic-lua`
and `sha256 =` the digest of `arg[-1]`'s bytes (`cosmic.hash`), and
print `pin: bin/cosmic.pin → <tag>`. A stamp of `unknown` prints `pin:
not rewritten (this is a tree build, not a release)` and leaves the
file. The pin is the trust root's input, so this is the ONE place the
binary writes it, and only to a value that names itself.

**`bin/cosmic upgrade`** (168 lines today, POSIX sh): a new verb
handled before `ensure_bootstrap`: `download` (existing helper,
line 76) `https://github.com/cosmic-lua/cosmic/releases/latest/download/cosmic-lua`
to `o/bootstrap/next.ape` (verified reachable 2026-09-05: `curl -sIL`
follows to the release asset), then `exec sh o/bootstrap/next.ape
--upgrade o/bootstrap/cosmic.ape "$@"` so the new release reports and
rewrites the pin against the old one, and the next `bin/cosmic` run
fetches what the pin now names. Everything network-facing stays in
the sh trust root, as D13 has it.

Tests: `_cli/upgrade_test.tl` — a fixture project in `TEST_TMPDIR`
with the five break shapes against two synthetic zips (the `--diff`
item's fixture, extended with a `.tl/cosmic/_gone/x.tl`); assert the
report's lines, the already-narrowed exemption, the missing-wrapper
wording, and the three exit codes. Pin rewrite: a fixture
`bin/cosmic.pin` and a stubbed stamp, asserting the two lines and the
refusal on `unknown`. The sh verb: `_cli/fence_test.tl`'s pattern for
running `bin/cosmic` with `COSMIC_FENCE=0` against a local file URL.

## Non-goals

No source rewriting (sibling). No release resolution inside the
binary. No `--docs` integration of the gone tree.
