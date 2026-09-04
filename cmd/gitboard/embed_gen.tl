--- gitboard's payload generator: the one thing it adds is `base`, the
--- runtime the artifact is built onto.
---
--- Without a `base` of its own a binary is built onto whatever cosmic
--- runs the build, and the trust root assimilates the pinned release
--- into a native ELF before running it, so the artifact would be a
--- Linux-only ELF. The pinned release as PUBLISHED is a fat APE that
--- runs on every platform cosmic does, so `3p/cosmic/cosmic_pin.tl`
--- names that same release and `--make fetch` lands it untouched at
--- `o/3p/cosmic/cosmic-lua`; this copies it in as `base`. The two pins
--- name one release: `embed_gen_test.tl` holds them together.
---
--- The default payload, gitboard's compiled modules, is staged by the
--- build as for any binary; nothing here touches it.
local fs = require("cosmic.fs")

--- The fetched release, relative to the project root.
local RUNTIME < const > = "o/3p/cosmic/cosmic-lua"

--- The name `build` reads the runtime under, in this unit's output
--- directory.
local BASE < const > = "base"

--- Copy the fetched runtime in as `base`.
--- @param out string This generator's output directory
--- @return string | nil The reason it could not, nil on success
local function generate(out: string): string | nil
  local body, rerr = fs.read(RUNTIME)
  if not body then
    return RUNTIME .. ": " .. (rerr or "cannot read") ..
    " (run `bin/cosmic --make fetch` to land the pinned release)"
  end
  local mok, merr = fs.make_dirs(out)
  if not mok then
    return out .. ": " .. (merr or "cannot create")
  end
  local dest = fs.join(out, BASE)
  local wok, werr = fs.write(dest, body)
  if not wok then
    return dest .. ": " .. (werr or "cannot write")
  end
  return nil
end

--- @param args {string} The unit's output directory, as argv
--- @return integer Exit code
local function main(args: {string}): integer
  local out = args[1]
  if not out or out == "" then
    io.stderr:write("embed_gen: usage: embed_gen.tl <outdir>\n")
    return 2
  end
  local err = generate(out)
  if err then
    io.stderr:write("embed_gen: " .. err .. "\n")
    return 1
  end
  return 0
end

local record EmbedGenModule
  RUNTIME: string
  generate: function(out: string): string | nil
  main: function(args: {string}): integer
end

local M: EmbedGenModule = {
  RUNTIME = RUNTIME,
  generate = generate,
  main = main,
}

-- A generator is run, not imported; the guard keeps `--check types`
-- and the compile step from executing it.
if arg and arg[0] and arg[0]:match("embed_gen%.tl$") then
  os.exit(main(arg))
end

return M
