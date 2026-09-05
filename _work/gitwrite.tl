--- The store's write path: turning one mutation's items into ONE
--- `git fast-import` stream (`_work.fastimport`), writing each item's
--- commit to whatever ref it is already on — `refs/heads/items/<id>`
--- stays `refs/heads/items/<id>` even when the write sets
--- `resolution`; a legacy item already under `refs/heads/ended/<id>`
--- stays there too. A resolution never moves a ref: the pushing
--- credential can create and update a branch but never delete one, so
--- a save that tried to create `refs/heads/ended/<id>` and delete
--- `refs/heads/items/<id>` in the same push could land the create and
--- lose the delete, leaving one id filed under both namespaces —
--- `_work.gitread` is where a reader tolerates and dedupes that. The
--- board's own outcome ranking is not a separate write here: it is one
--- of `req.items`' own `.order` field, diffed and committed exactly
--- like any other item's. Split out of `_work.store` so that
--- module stays under its line cap; `_work.store` is the only caller
--- outside tests.
local fastimport = require("_work.fastimport")
local item = require("_work.item")
local refs = require("_work.refs")

--- The tool's own git identity — the committer on every commit, and
--- the author too when no session claimed the mutation.
local TOOL_NAME < const > = "Claude"
local TOOL_EMAIL < const > = "noreply@anthropic.com"

--- One `save` call's inputs: the items to write (`items[1]` is the
--- primary `it`, the rest are `also`), the identity and trailer to
--- write them under, the lease each was last observed at, a snapshot
--- of each as OBSERVED (`leased_item` — the fast-import diff's
--- baseline; nil for an item never loaded, read as "brand new"), and
--- — for a BOUNDED mutation — `refs/heads/board/seq`'s own observed tip.
local record Request
  root: string
  items: {item.Item}
  message: string
  session: string
  op: string
  --- Replacement spec for `items[1]`; nil leaves it exactly as
  --- observed. Every other item's sidecar is always carried forward
  --- unchanged — untouched entirely, not even read, since `from`
  --- alone carries an unchanged path forward.
  spec_for_first: string | nil
  leased_ref: {string: string}
  leased_sha: {string: string}
  leased_item: {string: item.Item}
  bounded: boolean
  seq_sha: string
  read_spec: function(id: string): string
end

--- What `save_batch` did: the refs to push, each item's new ref and
--- tip (for the caller to update its own lease table with), whether
--- anything changed at all, and — for a bounded mutation — whether
--- `refs/heads/board/seq` moved and its new tip.
local record Outcome
  pushes: {refs.PushSpec}
  new_ref: {string: string}
  new_sha: {string: string}
  changed: boolean
  seq_changed: boolean
  new_seq_sha: string
end

--- One item's commit as planned, plus the bookkeeping the post-import
--- verification needs: the ref it targets — the ref it was already
--- on, `refs/heads/ended/<id>` for a legacy item being corrected in
--- place, `refs/heads/items/<id>` otherwise, resolution or not — and
--- the tip it was observed at.
local record Planned
  id: string
  ref: string
  old_sha: string
end

--- One item's diff, planned as a fast-import `CommitPlan` when it
--- changed — nil when `diff_item` found nothing to write, so the
--- caller adds neither a commit nor any bookkeeping for it.
--- @param req Request The save request
--- @param it item.Item The item to write
--- @param spec_replacement string | nil `items[1]`'s replacement spec; nil elsewhere
--- @param now string This save's commit date, shared by every commit it makes
--- @return fastimport.CommitPlan | nil The commit to add to the stream
--- @return Planned | nil Its bookkeeping, set together with the plan
local function plan_one(req: Request, it: item.Item,
    spec_replacement: string | nil, now: string):
  fastimport.CommitPlan | nil, Planned | nil
  local ref = req.leased_ref[it.id] or ("refs/heads/items/" .. it.id)
  local old_sha = req.leased_sha[it.id] or refs.ZERO_SHA
  local old = req.leased_item[it.id]
  local old_spec = ""
  -- An id never observed (not in the snapshot — `old_sha` still
  -- `ZERO_SHA`) has no existing ref to hold a spec sidecar, so reading
  -- one would only ever come back "" the hard way, one `cat-file -p`
  -- per candidate ref against a ref that does not exist yet.
  if spec_replacement ~= nil and old_sha ~= refs.ZERO_SHA then
    old_spec = req.read_spec(it.id)
  end
  local ops = fastimport.diff_item(old, it, spec_replacement, old_spec)
  if #ops == 0 then
    return nil
  end
  local author_name, author_email = TOOL_NAME, TOOL_EMAIL
  if (req.session or "") ~= "" then
    author_name, author_email = req.session, req.session .. "@board"
  end
  local from: string = nil
  if old_sha ~= refs.ZERO_SHA then
    from = old_sha
  end
  local plan: fastimport.CommitPlan = {
    ref = ref, from = from, author_name = author_name, author_email = author_email,
    author_date = now, committer_name = TOOL_NAME, committer_email = TOOL_EMAIL,
    committer_date = now, message = req.message, op = req.op or "", ops = ops,
  }
  return plan, {id = it.id, ref = ref, old_sha = old_sha}
end

--- Write every item in `req.items`, each as its own commit when its
--- diff found anything to move, and — when `req.bounded` — advance
--- `refs/heads/board/seq` too, ALL of it in one `git fast-import` stream.
--- Every commit lands on the ref its item was already leased on —
--- setting `resolution` is an ordinary field write, never a ref move —
--- so there is nothing else to do locally afterward. Every write
--- staged is left in `Outcome.pushes` for `publish` to push together.
--- @param req Request The save request
--- @return Outcome | nil What moved
--- @return string Error message
local function save_batch(req: Request): Outcome | nil, string
  local out: Outcome = {pushes = {}, new_ref = {}, new_sha = {}, changed = false,
    seq_changed = false, new_seq_sha = ""}
  local now = fastimport.git_date_now()
  local commits: {fastimport.CommitPlan} = {}
  local planned: {Planned} = {}
  for idx, it in ipairs(req.items) do
    local spec_replacement: string | nil = nil
    if idx == 1 then
      spec_replacement = req.spec_for_first
    end
    local plan, p = plan_one(req, it, spec_replacement, now)
    if plan ~= nil then
      commits[#commits + 1] = plan
      planned[#planned + 1] = p
    end
  end
  if #commits == 0 then
    return out, ""
  end
  local seq_old = ""
  if req.bounded then
    if (req.seq_sha or "") ~= "" then
      seq_old = req.seq_sha
    end
    local from: string = nil
    if seq_old ~= "" then
      from = seq_old
    end
    commits[#commits + 1] = {
      ref = "refs/heads/board/seq", from = from, author_name = TOOL_NAME,
      author_email = TOOL_EMAIL, author_date = now, committer_name = TOOL_NAME,
      committer_email = TOOL_EMAIL, committer_date = now, message = req.message,
      op = req.op or "", ops = {},
    }
  end
  local ok, err = fastimport.run(req.root, commits)
  if not ok then
    return nil, err
  end
  -- One `for-each-ref` learns every ref this stream just moved —
  -- fixed at one process regardless of how many items (and the seq
  -- bump) the batch touched.
  local patterns: {string} = {}
  for _, p in ipairs(planned) do
    patterns[#patterns + 1] = p.ref
  end
  if req.bounded then
    patterns[#patterns + 1] = "refs/heads/board/seq"
  end
  local found, ferr = refs.for_each_ref(req.root, patterns)
  if found == nil then
    return nil, ("fast-import applied, but its result could not be read back: %s")
    :format(ferr)
  end
  local new_sha_of: {string: string} = {}
  for _, r in ipairs(found) do
    new_sha_of[r.refname] = r.sha
  end
  for _, p in ipairs(planned) do
    local new_sha = new_sha_of[p.ref]
    -- fast-import silently refuses a non-fast-forward `from` instead
    -- of a non-zero exit — see `_work.fastimport`'s own doc — so "the
    -- ref did not move off what we observed" is read back here as the
    -- failure it is, the same guarantee `update-ref <ref> <new>
    -- <old>`'s explicit compare used to give this write.
    if new_sha == nil or new_sha == p.old_sha then
      return nil, ("fast-import did not fast-forward %s — refused (unexpected "
        .. "local state)"):format(p.ref)
    end
    out.pushes[#out.pushes + 1] = {ref = p.ref, old = p.old_sha}
    out.new_ref[p.id], out.new_sha[p.id] = p.ref, new_sha
  end
  if req.bounded then
    local new_seq = new_sha_of["refs/heads/board/seq"]
    if new_seq == nil or new_seq == seq_old then
      return nil, "fast-import did not fast-forward refs/heads/board/seq — refused "
      .. "(unexpected local state)"
    end
    out.pushes[#out.pushes + 1] = {ref = "refs/heads/board/seq", old = seq_old}
    out.seq_changed, out.new_seq_sha = true, new_seq
  end
  out.changed = true
  return out, ""
end

local record gitwrite
  type Request = Request
  type Outcome = Outcome
  save_batch: function(req: Request): Outcome | nil, string
end

local M: gitwrite = {
  save_batch = save_batch,
}

return M
