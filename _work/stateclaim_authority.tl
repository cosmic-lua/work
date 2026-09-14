--- Current canonical blobs, never speculative receipts, authorize native work.
local child = require("cosmic.child")
local boardread = require("_work.boardread")
local claim = require("_work.claim")
local refs = require("_work.refs")
local stateclaim = require("_work.stateclaim")
local store = require("_work.store")
--- Whether this session holds `id` NOW, read from the current `claims/<id>`
--- blob — never from the fact that a publication landed. A lease that expired
--- or belongs to someone else is no authority.
--- @param s store.Store An open store on a format-6 board
--- @param id string Item id
--- @param session string The session claiming to hold it
--- @return claim.State | nil The live lease this session holds
--- @return string Error message, or why it holds nothing
local function current(s: store.Store, id: string, session: string): claim.State | nil, string
  local ref = refs.board_mode(s.root) == "local" and "refs/heads/state"
  or "refs/remotes/" .. refs.board_remote(s.root) .. "/state"
  local head, herr = refs.read_ref(s.root, ref)
  if head == nil or head == refs.ZERO_SHA then return nil, herr ~= nil and herr ~= "" and herr or "canonical state is unavailable" end
  local got, err = boardread.load(s.root, head, id)
  if got == nil then return nil, err end
  local st = stateclaim.state(got.claim)
  if claim.status(st, os.time()) ~= "active" then return nil, "REFUSED: current claim is not active; claim it again" end
  if st == nil or st.holder ~= session then return nil, "REFUSED: current claim belongs to another session" end
  st.control = head
  return st, ""
end
--- Why a receipt naming `control` is not evidence of the lease `st`: a
--- reacquisition mints a new identity, and a control commit off the branch's
--- first-parent history never recorded this acquisition at all. "" when the
--- receipt does match the current acquisition.
--- @param s store.Store An open store on a format-6 board
--- @param id string Item id
--- @param control string The commit a worktree receipt recorded
--- @param st claim.State The lease currently recorded for `id`
--- @return string The refusal, "" when the receipt is current
local function historical(s: store.Store, id: string, control: string, st: claim.State): string
  local lineage, err = child.run({"git", "rev-list", "--first-parent", st.control}, {cwd = s.root})
  if lineage == nil then return err end
  if not lineage.ok then return "cannot inspect canonical receipt history: " .. lineage.stderr end
  local canonical = false
  for sha in lineage.stdout:gmatch("([^\n]+)") do
    if sha == control then canonical = true; break end
  end
  if not canonical then return "receipt control is not canonical first-parent history" end
  local old, oerr = boardread.load(s.root, control, id)
  if old == nil then return oerr end
  if old.claim == nil or old.claim.id ~= st.root or old.claim.holder ~= st.holder
  or old.claim.product_base ~= st.product_base then return "receipt control does not match acquisition" end
  return ""
end
local record Module
  current: function(store.Store, string, string): claim.State | nil, string
  historical: function(store.Store, string, string, claim.State): string
end
local M: Module = {current = current, historical = historical}
return M
