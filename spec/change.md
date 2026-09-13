Three files. Apply exactly these shapes (all validated):

**1. `cosmic/_teal_engine.tl:248`** — keep the cast, replace its
reason. The line becomes a cast under an above-line comment:

```teal
  -- The lazy in-function require keeps tl's own Result record
  -- un-nameable at file scope; TlResult is its structural mirror.
  -- cast: pcall slot 2 is tl's nominal Result, not any
  local result = result_or_err as TlResult
```

(The `-- cast:` marker must sit on the line DIRECTLY above the cast —
the cast-justify lint reads only that line and the cast's own.)

Nothing else in the file moves. Its `from any` count falls to 0; its
total cast count stays 4, so its baseline row stays `= 4`.

**2. `cmd/cosmic/main.tl`** — replace the pack-and-cast block (lines
474–483 today) with:

```teal
    -- run_chunk's wrapper returns a string so xpcall types (boolean, string)
    local ok, script_err = xpcall(function(): string
      run_chunk(table.unpack(args))
      return ""
    end, run.trim_traceback)
    if cov_dump then
      cov_dump()
    end
    if not ok then return 1, script_err end
    return 0
```

(Indentation per `cosmic --fix`; the refinement pass verified the
formatter's output.) The name is `script_err` because `err` shadows an
outer local at `:463` and shadowing is an error. Net −1 line: the file
lands at 499, back under the cap with headroom of 1.

**3. `cosmic/_seal_coverage.tl`** — declare the shape once and guard
once. After the module doc comment, add:

```teal
--- The two entry points seal_coverage() needs from cosmic.coverage,
--- declared here because the module is reached through package.loaded:
--- requiring it would force-load instrumentation a caller is not using.
local record CoverageModule
  is_kept_on_restrict: function(): boolean
  seal: function()
end
```

and the body becomes:

```teal
local function seal_coverage()
  local cov = package.loaded["cosmic.coverage"]
  if cov == nil or not (cov is CoverageModule) then
    return
  end
  local kept = cov.is_kept_on_restrict
  if kept ~= nil and kept() then
    return
  end
  cov.seal()
end
```

All three casts close on one `type(x) == "table"` test; the runtime
`kept ~= nil` check stays (an older loaded module may not carry the
function). The comment at `:5–15` explaining the `package.loaded` read
stays.

**The ratchet.** Run exactly the command the gate's failure message
prints — `bin/cosmic --make run _build/casts.tl --baseline` — and
commit the result. Expected rows:

| file | row today | row after |
| --- | --- | --- |
| `cosmic/_teal_engine.tl` | `= 4` | `= 4` (unchanged — reason edit only) |
| `cmd/cosmic/main.tl` | `= 3` | `= 1` |
| `cosmic/_seal_coverage.tl` | `= 3` | row absent |
