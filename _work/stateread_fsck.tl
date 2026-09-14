--- Native fsck audits canonical item subtrees and claims without mutating Git.
local boardread = require("_work.boardread")
local boardtree = require("_work.boardtree")
local gitobj = require("_work.gitobj")
local ksuid = require("_work.ksuid")
local archive = require("_work.migrate6_archive")
local refs = require("_work.refs")

--- Everything wrong with one format-6 head, in sorted order and mutating
--- nothing: a `format` blob that is not canonically `6`, retained migration
--- marks that no longer decode, a claim for an item that is absent, an item id
--- that is not a ksuid, and an item subtree whose bytes are not what its own
--- fields encode to. Empty when the head is sound.
--- @param root string The repository holding `head`
--- @param head string The exact commit to audit
--- @return {string} One line per problem, sorted; empty when there are none
local function problems(root: string, head: string): {string}
  local view, err = boardread.list(root, head)
  if view == nil then return {err} end
  local out: {string} = {}
  local queries: {string} = {head .. ":format"}
  local marks_sha = ""
  local sources_sha = ""
  for _, entry in ipairs(view.entries) do
    if entry.path == "migration/marks" then
      marks_sha = entry.sha
      queries[#queries + 1] = marks_sha
    elseif entry.path == "migration/sources" then
      sources_sha = entry.sha
      queries[#queries + 1] = sources_sha
    end
  end
  local batch, berr = gitobj.cat_file_batch(root, queries)
  if batch == nil then out[#out + 1] = berr
  else
    local marker = batch[head .. ":format"]
    local shown = marker ~= nil and marker.content:gsub("\\", "\\\\")
    :gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t") or ""
    local actual = marker == nil and "<missing>"
    or marker.otype ~= "blob" and "<" .. marker.otype .. ">" or '"' .. shown .. '"'
    if marker == nil or marker.otype ~= "blob" or marker.content ~= "6\n" then
      out[#out + 1] = "state: format is " .. actual .. ", expected canonical \"6\\n\""
    end
    if marks_sha ~= "" then
      local marks = batch[marks_sha]
      if marks == nil or marks.otype ~= "blob" then
        out[#out + 1] = "migration/marks: unreadable blob"
      else
        local decoded, merr = boardtree.decode_marks(marks.content)
        if decoded == nil then out[#out + 1] = "migration/marks: " .. merr end
      end
    end
    if marks_sha ~= "" and sources_sha == "" then
      out[#out + 1] = "migration/sources: missing archive witness"
    end
    if sources_sha ~= "" then
      local sources = batch[sources_sha]
      if sources == nil or sources.otype ~= "blob" then
        out[#out + 1] = "migration/sources: unreadable blob"
      else
        local prefix = refs.board_mode(root) == "local" and "refs/heads/"
        or "refs/remotes/" .. refs.board_remote(root) .. "/"
        for _, problem in ipairs(archive.problems(root, sources.content, prefix)) do
          out[#out + 1] = problem
        end
      end
    end
  end
  for id in pairs(view.claims_by_id) do
    if view.items_by_id[id] == nil then out[#out + 1] = "claims/" .. id .. ": item is absent" end
  end
  for _, it in ipairs(view.items) do
    if not ksuid.is_id(it.id) then out[#out + 1] = "items/" .. it.id .. ": invalid item id" end
    local rebuilt, rerr = boardtree.rebuild_item(root, it, view.specs_by_id[it.id],
      view.raw_logs_by_id[it.id], view.item_tree_by_id[it.id])
    if rebuilt == nil then out[#out + 1] = "items/" .. it.id .. ": " .. rerr
    elseif rebuilt ~= view.item_tree_by_id[it.id] then
      out[#out + 1] = "items/" .. it.id .. ": canonical form drifted"
    end
  end
  table.sort(out)
  return out
end
return {problems = problems}
