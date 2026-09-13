One file: `cosmic/sqlite/init.tl`. Measured `wc -l cosmic/sqlite/init.tl`
= **448**, so **52 lines of headroom** under the 500-line cap — this
change adds about 6, but the cap is close enough that Acceptance bounds
it.

**1. The module header example (lines 14-21) must compile.** It does not
today. Measured 2026-08-24 at `9bcb0f7d`, copying the block verbatim
into a file and running `o/bin/cosmic --check types` on it: **7 errors**,
from three independent causes — `sqlite.open` returns `Database | nil`
and is never narrowed (4 errors, plus 2 cascading `unknown variable:
row`), and `db:close()` discards a fallible return (1). With the
narrowing repaired, the discard check alone gives 2 errors, on
`db:exec` and `db:close`:

    discarded error return of function(Database): (boolean, string)
      — capture it: `local v, err = f(...)` (or `local _ok, _err = f(...)`
      for deliberate fire-and-forget; assert/check.must in tests)

Replace the indented block at lines 14-21 with this fenced one. It is
verified: `--check types` passes clean at full strictness and
`--check fmt` reports it a formatter fixpoint, both run 2026-08-24 on
the body below exactly as written.

    ```teal
    local sqlite = require("cosmic.sqlite")
    local db = assert(sqlite.open(":memory:"))
    assert(db:exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)"))
    assert(db:exec("INSERT INTO users (name) VALUES (?)", {"alice"}))
    for row in assert(db:query("SELECT * FROM users WHERE name = :n", {n = "alice"})) do
      print(row.id, row.name)
    end
    assert(db:close())
    ```

**The fence is load-bearing, not cosmetic.** `_build/snippets_test.tl`
collects doc-comment code only from fences (`doc_comment_fences`, lines
162-192, matching "^```(%w*)"), and holds every `teal`- or `lua`-tagged
fence to both the formatter and the checker at full strictness
(`test_every_snippet_is_a_formatter_fixpoint`, line 220;
`test_every_snippet_compiles`, line 245). An indented block is collected
by nothing. Converting this one puts it permanently under the gate, so
it cannot rot again — which is why the conversion is in scope and a
plain in-place repair of the indented block would not be. Precedent for
the form: `cosmic/shm.tl:288`, the file the gate's own header names.

**2. The one-line note beside `close`.** `close` is declared at line 145
and its doc comment runs 138-144; it already explains the failure mode
in detail but never tells the reader to capture the return. Add one
sentence to that existing comment saying `close()` returns
`boolean, string` like every other fallible Database method, so it must
be captured — `assert(db:close())`, or `local _ok, _err = db:close()`
for deliberate fire-and-forget. This is the eval agent's own ask,
quoted: "the fix is pure boilerplate (local _ok, _err = ...) with no way
to write it once."
