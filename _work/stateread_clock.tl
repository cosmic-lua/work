--- Native item rows project claim authority at a particular wall-clock instant.
--- A Git head alone cannot keep that projection valid across a lease expiry.
local boardread = require("_work.boardread")
local cachedb = require("_work.cachedb")
local sqlite = require("cosmic.sqlite")

--- Record when this projection was taken and the first instant it can be wrong
--- — the earliest live lease's expiry, or 0 when no lease can expire. An
--- unchanged head is not enough to keep native item rows valid, because a
--- lease expiring turns a claimed item into an unclaimed one with no commit.
--- @param db sqlite.Database The index being written
--- @param view boardread.View The projection just filled in
--- @return boolean True on success
--- @return string Error message
local function record_projection(db: sqlite.Database, view: boardread.View): boolean, string
  local deadline = 0
  for _, claim in pairs(view.claims_by_id) do
    if claim.expires_at > view.projected_at and (deadline == 0 or claim.expires_at < deadline) then
      deadline = claim.expires_at
    end
  end
  local ok, err = cachedb.meta_set(db, "native_projected_at", tostring(view.projected_at))
  if not ok then return false, err end
  return cachedb.meta_set(db, "native_valid_until", tostring(deadline))
end

--- Whether an index's native rows still describe the board: taken in the past
--- and before the deadline `record_projection` recorded. An older native cache
--- with no clock recorded is not fresh, and a legacy cache — whose digest is a
--- namespace hash rather than a 40-character head — is not judged here at all.
--- @param db sqlite.Database The index to judge
--- @param now integer | nil The instant to judge at, defaulting to the clock
--- @return boolean True when the rows may still be read
local function fresh(db: sqlite.Database, now?: integer): boolean
  local recorded = cachedb.meta_get(db, "native_projected_at")
  if recorded == nil then
    -- Native freshness is a Git SHA-1 head; legacy freshness is a SHA-256
    -- namespace digest. A missing clock on an older native cache must rebuild.
    return #(cachedb.meta_get(db, "refs_digest") or "") ~= 40
  end
  local at = tonumber(recorded)
  local deadline = tonumber(cachedb.meta_get(db, "native_valid_until") or "")
  if at == nil or deadline == nil then return false end
  local clock = now or os.time()
  return clock >= at and (deadline == 0 or clock < deadline)
end
return {record_projection = record_projection, fresh = fresh}
