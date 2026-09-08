--- Provider-free repository identity derived from local Git configuration.
--- Reading a remote URL is local inspection, never authenticated transport;
--- provider API calls belong in `_work.gh`, which consumes this module rather
--- than making every slug consumer depend on the network client.
local child = require("cosmic.child")
local refs = require("_work.refs")
local store = require("_work.store")

--- Read the configured board remote's URL once per Store. The remote name is
--- caller-selected (`gitboard.remote`/`--remote`), never hardcoded to origin.
local function read_remote_url(s: store.Store)
  if s.remote_url_read then return end
  s.remote_url_read = true
  local remote = refs.board_remote(s.root)
  local r, err = child.run({"git", "remote", "get-url", remote}, {cwd = s.root})
  if r == nil then
    s.remote_url_ok, s.remote_url = false, err or ""
  elseif not r.ok then
    s.remote_url_ok = false
    s.remote_url = ("no %s remote: %s"):format(remote,
      ((r.stderr or ""):gsub("%s+$", "")))
  else
    s.remote_url_ok = true
    s.remote_url = (r.stdout or ""):gsub("%s+$", "")
  end
end

--- The `owner/repo` a caller addresses: an explicit item repo verbatim,
--- otherwise the configured board remote. Both GitHub URL forms are accepted.
local function slug(s: store.Store, repo: string | nil): string | nil, string
  if (repo or "") ~= "" then return repo, "" end
  read_remote_url(s)
  if not s.remote_url_ok then return nil, s.remote_url end
  local owner, name = s.remote_url:match("github%.com[:/]([^/]+)/(.+)$")
  if owner == nil then
    return nil, ("board remote is not a github remote: %s"):format(s.remote_url)
  end
  return ("%s/%s"):format(owner, (name:gsub("%.git$", ""))), ""
end

local record gitslug
  slug: function(s: store.Store, repo: string | nil): string | nil, string
end

local M: gitslug = {slug = slug}
return M
