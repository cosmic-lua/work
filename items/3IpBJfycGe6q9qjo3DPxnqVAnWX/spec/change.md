- **`cosmic/sqlite/lifecycle_test.tl:10-13`** — replace
  `check.must(db:query_one(...)).n as integer` with
  `check.must(sqlite.column_integer(check.must(db:query_one(...)), "n"))`,
  or, more readably, bind the row to a local first:

  ```teal
  local function count_rows(db: sqlite.Database): integer
    local row = check.must(db:query_one("SELECT COUNT(*) AS n FROM t"))
    return check.must(sqlite.column_integer(row, "n"))
  end
  ```

  Delete the `-- cast: a row column is \`any\`` comment with it.

- **`cosmic/sqlite/extras_test.tl:46-49`** — the same rewrite with
  `sqlite.column_number`, since this file's `count` is declared to
  return `number`:

  ```teal
  local function count(db: sqlite.Database): number
    local row = check.must(db:query_one("SELECT COUNT(*) AS n FROM t"))
    return check.must(sqlite.column_number(row, "n"))
  end
  ```

Confirm `sqlite` (the `require("cosmic.sqlite")` local) is already
imported in both files before writing the calls — both already call
other `sqlite.*` functions in the same file, so no new import is
needed.

Regenerate and reconcile:

    bin/cosmic --make run _build/casts.tl --baseline
    bin/cosmic --make run _build/cast_sites.tl --reconcile

Confirm the class is empty:

    git show HEAD:docs/design/cast-sites.tsv | awk -F'\t' '$3=="sqlite row column read"'   # (after committing) — empty

and delete the now-empty `### sqlite row column read` heading (through
its body, to the next `###` or `##`) from `docs/design/casts.md`,
following the precedent
`git show cf416d85 -- docs/design/casts.md | grep '^-###'` (that
commit deleted `### proved-value narrowing` in the same PR that
emptied its class).

Gate with `bin/cosmic --make ci`; `_build/cast_sites_test.tl` checks
the reconciled tsv against a fresh lexer walk and every remaining
`### ` heading.
