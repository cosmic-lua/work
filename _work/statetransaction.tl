--- Shared transition shapes and path validation.
local record Dependency
  path: string
  id: string
end
local record Change
  path: string
  mode: string
  content: string
  delete: boolean
end
local record Author
  name: string
  email: string
  date: string
end
local record Transition
  base: string
  dependencies: {Dependency}
  changes: {Change}
  message: string
  author: Author
  publish_by: integer
  bounded: boolean
  gate: string
end

--- Whether a transition path is relative and unambiguous.
local function path_ok(path: string): boolean
  return path ~= "" and path:sub(1, 1) ~= "/" and path:sub(-1) ~= "/"
  and not path:find("[%z\n\r\t]") and not path:find("//", 1, true)
  and not ("/" .. path .. "/"):find("/../", 1, true)
  and not ("/" .. path .. "/"):find("/./", 1, true)
end

local record Module
  type Dependency = Dependency
  type Change = Change
  type Author = Author
  type Transition = Transition
  path_ok: function(string): boolean
end
local M: Module = {path_ok = path_ok}
return M
