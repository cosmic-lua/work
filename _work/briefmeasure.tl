--- The `## Measured at brief time` section `_work.brief` appends to a
--- builder or review brief when the caller passes `--tree`: every Teal
--- path the item's declared `touches` list names, its current line
--- count against the 500-line cap, or `absent` when the path does not
--- exist in that checkout. Split out of `_work.brief` for headroom
--- under the 500-line cap — a caller-facing feature with no board
--- state of its own, so it needs nothing from `_work.brief` but the
--- declared list and the checkout to measure.
local child = require("cosmic.child")
local fs = require("cosmic.fs")

--- The Teal paths in the item's declared list, once each and in
--- declared order — the line cap is a `.tl` rule, so a declared
--- markdown or data path is not measured.
--- @param touches {string} The item's declared `touches` list
--- @return {string} Its `.tl` paths, first-seen order
local function teal_paths(touches: {string}): {string}
  local paths: {string} = {}
  local seen: {string: boolean} = {}
  for _, path in ipairs(touches) do
    if path:match("%.tl$") ~= nil and not seen[path] then
      seen[path] = true
      paths[#paths + 1] = path
    end
  end
  return paths
end

--- Measure the declared Teal paths from a caller-provided product
--- checkout.
--- @param touches {string} The item's declared `touches` list
--- @param tree string The checkout to measure beneath
--- @return string | nil The appended section, or nil on failure
--- @return string The failure detail, empty on success
local function measure(touches: {string}, tree: string): string | nil, string
  local rev, rerr = child.run({"git", "rev-parse", "--short", "HEAD"},
    {cwd = tree})
  if rev == nil then
    return nil, rerr or "could not resolve the tree's HEAD"
  end
  if not rev.ok then
    return nil, (rev.stderr or "could not resolve the tree's HEAD")
  end
  local head = rev.stdout:match("%S+") or ""
  if head == "" then
    return nil, "the tree's HEAD was empty"
  end
  local rows: {string} = {}
  for _, path in ipairs(teal_paths(touches)) do
    local full = fs.join(tree, path)
    if not fs.is_file(full) then
      rows[#rows + 1] = path .. "  absent"
    else
      local operand = path
      if path:sub(1, 1) == "-" then
        operand = "./" .. path
      end
      local count, werr = child.run({"wc", "-l", operand}, {cwd = tree})
      if count == nil then
        return nil, werr or ("could not count " .. path)
      end
      if not count.ok then
        return nil, (count.stderr or ("could not count " .. path))
      end
      local n = math.tointeger(tonumber(count.stdout:match("%d+")))
      if n == nil then
        return nil, "wc returned no line count for " .. path
      end
      local marker = ""
      if n <= 500 and 500 - n <= 40 then
        marker = (" (%d under the 500 cap)"):format(500 - n)
      elseif n > 500 then
        marker = (" (%d over the 500 cap)"):format(n - 500)
      end
      rows[#rows + 1] = ("%s  %d lines%s"):format(path, n, marker)
    end
  end
  return ("## Measured at brief time (%s, %s)\n%s"):format(tree, head,
    table.concat(rows, "\n")), ""
end

local record briefmeasure
  measure: function(touches: {string}, tree: string): string | nil, string
end

local M: briefmeasure = {
  measure = measure,
}

return M
