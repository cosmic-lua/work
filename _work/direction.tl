--- Bounded textual direction hints, never readiness or admission evidence.
local itemtree = require("_work.itemtree")

-- Strip fenced and blockquoted examples before scanning across paragraphs.
-- Both Markdown fence characters are recognized; closing runs must be at
-- least as long as the opener. Quotes may span lines. Apostrophes within
-- words are not quote openers. Backticks remain for anchor recognition.
local function prose_only(change: string): string
  local lines: {string} = {}
  local fence = ""
  for line in (change .. "\n"):gmatch("([^\n]*)\n") do
    if not line:match("^%s*>") then
      local run = line:match("^%s*(```+)") or line:match("^%s*(~~~+)") or ""
      if fence ~= "" then
        if run:sub(1, 1) == fence:sub(1, 1) and #run >= #fence then
          fence = ""
        end
      elseif run ~= "" then
        fence = run
      else
        lines[#lines + 1] = line
      end
    end
  end
  local text = table.concat(lines, "\n")
  text = text:gsub('"[^"]*"', " ")
  text = text:gsub("^'[^']*'", " ")
  text = text:gsub("([^%w_])'[^']*'", "%1 ")
  return text
end

-- Limited anchors: an inline backticked identifier (possibly qualified),
-- a slash path that ends in a source extension or starts at the tree's
-- root, a dotted or underscore identifier with at least two identifier
-- characters on each side of every separator, or the introduction
-- `set NAME:` / `list NAME:`. These are pointers only: none establishes
-- that a referent exists.
local SOURCE_EXTENSIONS < const >: {string: boolean} = {tl = true, lua = true,
  md = true, c = true, h = true, mk = true, yml = true, sh = true}
local TREE_ROOTS < const > = {"_work/", "cosmic/", "_cli/", "_make/", "docs/",
  "skills/", "cmd/", "bin/"}

local function path_anchor(token: string): boolean
  token = token:gsub("%.+$", "")
  if not token:find("/", 1, true) then return false end
  if token:match("^[_/]") or token:match("^%./") then return true end
  for _, root in ipairs(TREE_ROOTS) do
    if token:sub(1, #root) == root then return true end
  end
  local extension = token:match("%.(%w+)$")
  return extension ~= nil and SOURCE_EXTENSIONS[extension] == true
end

local function identifier_anchor(token: string): boolean
  token = token:gsub("^%.+", ""):gsub("%.+$", "")
  local separator = token:find(".", 1, true) and "." or "_"
  if not token:find(separator, 1, true) then return false end
  for part in (token .. separator):gmatch("([^" .. separator .. "]*)" .. separator) do
    if separator == "." then
      if not part:match("^[%a_][%w_]+$") then return false end
    elseif not part:match("^%a%w+$") then
      return false
    end
  end
  return true
end

local function anchored(text: string): boolean
  if text:match("`[%a_][%w_%.:]*`")
  or text:match("`[%w_.%-]+/[%w_./%-]*`") then return true end
  local plain = text:gsub("`[^`]*`", " ")
  for token in plain:gmatch("%f[%w_./%-][%w_./%-]+") do
    if path_anchor(token) then return true end
  end
  for token in plain:gmatch("%f[%w_.][%w_.]+") do
    if identifier_anchor(token) then return true end
  end
  local lower = plain:lower()
  return lower:match("%f[%a]set%s+[%a_][%w_%-]*%s*:") ~= nil
  or lower:match("%f[%a]list%s+[%a_][%w_%-]*%s*:") ~= nil
end

local function hints(sp: itemtree.Spec | nil): {string}
  if sp == nil then return {} end
  local text = prose_only(sp.change or "")
  if anchored(text) then return {} end
  text = text:gsub("`[^`]*`", " "):lower():gsub("%s+", " ")
  local out: {string} = {}
  for _, family in ipairs({
      {"every spawned agent", "all callers", "all the callers",
        "each template", "every template", "all templates"},
      {"already knows", "already records", "already recorded", "the caller has it"},
    }) do
    for _, phrase in ipairs(family) do
      if text:find("%f[%w_]" .. phrase .. "%f[^%w_]", 1, false) then
        out[#out + 1] = 'direction-advisory: "' .. phrase
        .. '" has no recognized direction anchor in Change; where should '
        .. 'the builder look for the set/source pointer? This hint is advisory.'
        break
      end
    end
  end
  return out
end

local record direction
  hints: function(sp: itemtree.Spec | nil): {string}
end
local M: direction = {hints = hints}
return M
