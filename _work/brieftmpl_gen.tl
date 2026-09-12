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

local fs = require("cosmic.fs")
local source = require("_work.brieftmpl_source")

--- Write `text` to `path` only when its bytes differ from what is
--- already there.
--- @param path string The file to write
--- @param text string The bytes it should hold
--- @return boolean, string Success, or false plus the reason
local function write_if_changed(path: string, text: string): boolean, string
  if fs.read(path) == text then
    return true
  end
  local ok, err = fs.write(path, text)
  if not ok then
    return false, ("could not write %s: %s"):format(path, tostring(err))
  end
  return true
end

--- Compile every template and write what it produced.
--- @return boolean, string Success, or false plus the reason
local function run(): boolean, string
  local mok, merr = fs.make_dirs(source.OUT_DIR)
  if not mok then
    return false, ("could not create %s: %s"):format(source.OUT_DIR, tostring(merr))
  end
  for _, u in ipairs(source.UNITS) do
    local out, cerr = source.module_source(u)
    if out == nil then
      return false, ("%s: %s"):format(u.name, cerr)
    end
    local ok, werr = write_if_changed(
      ("%s/%s.tl"):format(source.OUT_DIR, u.name), out)
    if not ok then
      return false, werr
    end
  end
  return write_if_changed(("%s/fields.tl"):format(source.OUT_DIR),
    source.fields_module(source.UNITS))
end

local ok, err = run()
if not ok then
  io.stderr:write("brieftmpl_gen: " .. err .. "\n")
  os.exit(1) -- exits: a generator is a process boundary with no caller
end
