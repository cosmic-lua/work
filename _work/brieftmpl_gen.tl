--- The brief templates' build-time compiler: every template in
--- `_work.brieftext` and `_work.brieftext_review` becomes a typed
--- renderer module under `_work/brieftmpl/`, plus the caller-fill
--- token list each one declares. What it generates is
--- `_work.brieftmpl_source`; this is the writing of it.
---
--- A `*_gen.tl`, so `cosmic --make` runs it before the graph on every
--- verb that touches one: editing a template's text regenerates its
--- renderer, and the ordinary compile, check, fmt and lint rules then
--- gate the generated Teal like any other source. Because the
--- generated modules are what `_work.brief` requires and what the
--- `o/bin/gitboard` artifact embeds, they are COMMITTED: `o/` is
--- outside the project scan and outside the module path, so a
--- generated module that lived only there would be invisible to both
--- the graph and the binary.
---
--- Writes are content-comparing: an unchanged template leaves its
--- module's bytes and mtime alone, so a build does not recompile the
--- world to prove nothing moved.
---
--- Having repaired, it REFUSES: a run that had to rewrite a module
--- names it and exits non-zero. That a committed renderer was not what
--- its template compiles to is a fact only this program ever sees —
--- the repair is what destroys it, and it happens before the graph, so
--- no test can read the drift off disk afterwards. Nor can a test be
--- told to look: a test's result is recorded against its declared
--- inputs, a declaration may not name a build output, and this fact is
--- one, so a recorded answer would outlive the run that produced it in
--- both directions. The check therefore lives where the fact does.
---
--- The refusal clears itself: the repair has landed by the time it is
--- reported, so the next invocation has nothing to rewrite and passes.
--- One red verb per stale checkout, naming the files to commit.

local fs = require("cosmic.fs")
local source = require("_work.brieftmpl_source")

--- Write `text` to `path` only when its bytes differ from what is
--- already there, appending `path` to `rewrote` when they did.
--- @param path string The file to write
--- @param text string The bytes it should hold
--- @param rewrote {string} The paths this run has rewritten so far
--- @return boolean, string Success, or false plus the reason
local function write_if_changed(path: string, text: string,
    rewrote: {string}): boolean, string
  if fs.read(path) == text then
    return true
  end
  local ok, err = fs.write(path, text)
  if not ok then
    return false, ("could not write %s: %s"):format(path, tostring(err))
  end
  rewrote[#rewrote + 1] = path
  return true
end

--- The refusal a run earns by having had to rewrite something.
--- @param rewrote {string} The paths this run rewrote, in module order
--- @return string | nil The refusal, or nil when nothing was rewritten
local function stale_refusal(rewrote: {string}): string | nil
  if #rewrote == 0 then
    return nil
  end
  local names = table.concat(rewrote, "\n  ")
  return "the committed renderers were not what their templates compile to,"
  .. " so this run rewrote them:\n  " .. names
  .. "\ncommit what it wrote — the next run has nothing to report"
end

--- Compile every template, write what it produced, and refuse when a
--- module on disk was not already what its template compiles to.
--- @return boolean, string Success, or false plus the reason
local function run(): boolean, string
  local mok, merr = fs.make_dirs(source.OUT_DIR)
  if not mok then
    return false, ("could not create %s: %s"):format(source.OUT_DIR, tostring(merr))
  end
  local rewrote: {string} = {}
  for _, u in ipairs(source.UNITS) do
    local out, cerr = source.module_source(u)
    if out == nil then
      return false, ("%s: %s"):format(u.name, cerr)
    end
    local ok, werr = write_if_changed(
      ("%s/%s.tl"):format(source.OUT_DIR, u.name), out, rewrote)
    if not ok then
      return false, werr
    end
  end
  local fok, ferr = write_if_changed(("%s/fields.tl"):format(source.OUT_DIR),
    source.fields_module(source.UNITS), rewrote)
  if not fok then
    return false, ferr
  end
  local stale = stale_refusal(rewrote)
  if stale ~= nil then
    return false, stale
  end
  return true
end

local ok, err = run()
if not ok then
  io.stderr:write("brieftmpl_gen: " .. err .. "\n")
  os.exit(1) -- exits: a generator is a process boundary with no caller
end
