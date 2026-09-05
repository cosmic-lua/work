--- The store's write half: `save` (and the `add_pending` it uses to
--- queue a ref for `_work.publish`), `save_root_order` for
--- `refs/heads/board/order` alone, plus the lease/CAS bookkeeping a
--- verb sets on the `Store` before calling it — `set_session`,
--- `set_op`, `set_bounded`. Split out of `_work.store` so that module
--- stays under its line cap; this module requires it back for the
--- `Store` type and the pieces of the read half `save` itself needs
--- (`stage`'s validation, `read_spec` for its unmoved-sidecar default,
--- `snapshot_item` for the post-write baseline, `NOOP_PREFIX` for its
--- own no-op message) — `_work.store` never requires this module.
local item = require("_work.item")
local gitwrite = require("_work.gitwrite")
local refs = require("_work.refs")
local store = require("_work.store")

--- Record the session `save` should credit as author for whatever it
--- writes next — the identity a verb that knows its caller threads
--- through the store rather than through `save`'s own signature, which
--- stays fixed. Sticks until changed; a verb that never calls this
--- leaves every write of its own attributed to the tool identity.
--- @param s store.Store The store
--- @param session string The session's identity, "" for none
local function set_session(s: store.Store, session: string)
  s.session = session or ""
end

--- Record the `Op:` trailer `save` should add to its next commit(s).
--- @param s store.Store The store
--- @param op string The verb name, "" for none
local function set_op(s: store.Store, op: string)
  s.op = op or ""
end

--- Mark the next `save` as a BOUNDED mutation: it also advances and
--- leases `refs/heads/board/seq`, so two bounded mutations racing each
--- other cannot both land. Consumed by `save`, which resets it.
--- @param s store.Store The store
--- @param bounded boolean Whether the next save is bounded
local function set_bounded(s: store.Store, bounded: boolean)
  s.bounded = bounded or false
end

--- Queue one ref for the next `publish`, merging with whatever this
--- checkout already owes it a push for. A second unpublished write to
--- a ref this session already queued (`save` called again before
--- `publish` — a fixture writing straight past a verb, say) must
--- still lease against the tip the REMOTE last agreed to, not the
--- intermediate value this checkout only ever held locally, so the
--- existing entry — `old` included — is left exactly as it is; there
--- is nothing else on a `PushSpec` a later write to the same ref could
--- change.
--- @param s store.Store The store
--- @param p refs.PushSpec The ref to push
local function add_pending(s: store.Store, p: refs.PushSpec)
  for _, existing in ipairs(s.pending) do
    if existing.ref == p.ref then
      return
    end
  end
  s.pending[#s.pending + 1] = p
end

--- Write one item (and, when given, further items the same mutation
--- touches) as one commit PER item, moved locally, and left for
--- `publish` to push together in one atomic transaction — the
--- multi-ref replacement for "every mutation is one commit": the
--- atomicity now lives at the push, not at the git commit object.
--- Each item's new tree is compared against the one its observed tip
--- already carries; the whole call is the no-op success only when
--- NOTHING moved.
--- @param s store.Store The store
--- @param it item.Item The item
--- @param message string Commit subject, shared by every commit this call makes
--- @param spec string Replacement spec markdown for `it`; nil leaves its sidecar
--- exactly as observed
--- @param also {item.Item} Further items to write in the same mutation
--- @return boolean True on success — a no-op mutation succeeds too
--- @return string "" on an ordinary success; on a no-op, the `store.is_noop`-testable
--- "nothing to record: ..." message; the failure detail otherwise
local function save(s: store.Store, it: item.Item, message: string,
    spec?: string, also?: {item.Item}): boolean, string
  local batch: {item.Item} = {it}
  for _, other in ipairs(also or {}) do
    batch[#batch + 1] = other
  end
  for _, x in ipairs(batch) do
    local ok, err = store.stage(s, x)
    if not ok then
      return false, err
    end
  end
  local function read_current_spec(id: string): string
    return store.read_spec(s, id)
  end
  local outcome, oerr = gitwrite.save_batch({
      root = s.root, items = batch, message = message, session = s.session,
      op = s.op, spec_for_first = spec, leased_ref = s.leased_ref,
      leased_sha = s.leased_sha, leased_item = s.leased_item,
      bounded = s.bounded, seq_sha = s.observed_seq,
      root_order = nil, observed_root_order = s.observed_root_order,
      order_sha = s.observed_order_sha,
      read_spec = read_current_spec,
    })
  if outcome == nil then
    return false, oerr
  end
  s.bounded = false
  if not outcome.changed then
    return true, store.NOOP_PREFIX .. ("%s leaves the board unchanged"):format(message)
  end
  s.fresh_lease = ""
  local written_by_id: {string: item.Item} = {}
  for _, x in ipairs(batch) do
    written_by_id[x.id] = x
  end
  for id, ref in pairs(outcome.new_ref) do
    s.leased_ref[id] = ref
    s.leased_sha[id] = outcome.new_sha[id]
    -- A later save in the same store handle (another `also` batch, a
    -- second verb call) has to diff against what THIS save just
    -- wrote, not the state it was leased against a moment ago.
    local written = written_by_id[id]
    if written ~= nil then
      s.leased_item[id] = store.snapshot_item(written)
    end
  end
  if outcome.seq_changed then
    s.observed_seq = outcome.new_seq_sha
  end
  for _, p in ipairs(outcome.pushes) do
    add_pending(s, p)
  end
  return true, ""
end

--- Write a new root ranking to `refs/heads/board/order`, leased
--- against the tip `store.list` last observed for it — the
--- board-level counterpart to `save`, for a mutation that touches no
--- item at all (`refs/heads/board/seq` plays no part: the ref's own
--- tip is the lease, per `docs/design/order.md`). No verb calls this
--- yet.
--- @param s store.Store The store
--- @param ids {string} The new root ranking, in rank order
--- @param message string Commit subject
--- @return boolean True on success — a no-op mutation succeeds too
--- @return string "" on an ordinary success; on a no-op, the
--- `store.is_noop`-testable "nothing to record: ..." message; the
--- failure detail otherwise
local function save_root_order(s: store.Store, ids: {string}, message: string):
  boolean, string
  local function no_spec(_id: string): string
    return ""
  end
  local outcome, oerr = gitwrite.save_batch({
      root = s.root, items = {}, message = message, session = s.session,
      op = s.op, spec_for_first = nil, leased_ref = s.leased_ref,
      leased_sha = s.leased_sha, leased_item = s.leased_item,
      bounded = false, seq_sha = s.observed_seq,
      root_order = ids, observed_root_order = s.observed_root_order,
      order_sha = s.observed_order_sha,
      read_spec = no_spec,
    })
  if outcome == nil then
    return false, oerr
  end
  if not outcome.changed then
    return true, store.NOOP_PREFIX .. ("%s leaves the board unchanged"):format(message)
  end
  if outcome.order_changed then
    s.observed_order_sha = outcome.new_order_sha
    s.observed_root_order = ids
  end
  for _, p in ipairs(outcome.pushes) do
    add_pending(s, p)
  end
  return true, ""
end

local record storewrite
  set_session: function(s: store.Store, session: string)
  set_op: function(s: store.Store, op: string)
  set_bounded: function(s: store.Store, bounded: boolean)
  add_pending: function(s: store.Store, p: refs.PushSpec)
  save: function(s: store.Store, it: item.Item, message: string, spec?: string,
  also?: {item.Item}): boolean, string
  save_root_order: function(s: store.Store, ids: {string}, message: string): boolean, string
end

local M: storewrite = {
  set_session = set_session,
  set_op = set_op,
  set_bounded = set_bounded,
  add_pending = add_pending,
  save_root_order = save_root_order,
  save = save,
}

return M
