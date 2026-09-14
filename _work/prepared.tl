--- Explicit caller-owned Git execution, shared by native publication.
local child = require("cosmic.child")
local function execute(root: string, argv: {string}): boolean, string
  local r, err = child.run(argv, {cwd = root})
  if r == nil then
    return false, err
  end
  if not r.ok then
    local detail = (r.stderr or r.stdout):gsub("%s+$", "")
    return false, detail
  end
  return true, ""
end
return {execute = execute}
