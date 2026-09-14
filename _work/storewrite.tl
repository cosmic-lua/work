--- The store's write half: `save` (and the `add_pending` it uses to
--- queue a ref for `_work.publish`), plus the lease/CAS bookkeeping a
--- verb sets on the `Store` before calling it — `set_session`,
--- `set_op`, `set_bounded`. Split out of `_work.store` so that module
--- stays under its line cap; this module requires it back for the
--- `Store` type and the pieces of the read half `save` itself needs
--- (`stage`'s validation, `read_spec` for its unmoved-sidecar default,
--- `snapshot_item` for the post-write baseline, `NOOP_PREFIX` for its
--- own no-op message) — `_work.store` never requires this module.
--- `save` also refuses, before staging anything, when the store's root
--- is a linked worktree of another checkout (`_work.storeinit`'s
--- `linked_worktree_refusal` — the same guard `init_repo` runs, so
--- there is one implementation of the check, not two).
local statewrite = require("_work.statewrite")
local item = require("_work.item")
local format = require("_work.format")
local itemtree = require("_work.itemtree")
local store = require("_work.store")
local storeinit = require("_work.storeinit")

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

--- Mark the next save as a bounded native transition, fencing the whole head.
--- @param s store.Store The store
--- @param bounded boolean Whether the next save is bounded
local function set_bounded(s: store.Store, bounded: boolean)
  s.bounded = bounded or false
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
--- @param spec itemtree.Spec Replacement prose for `it`; nil leaves its
--- `spec/` subtree exactly as observed
--- @param also {item.Item} Further items to write in the same mutation
--- @return boolean True on success — a no-op mutation succeeds too
--- @return string "" on an ordinary success; on a no-op, the `store.is_noop`-testable
--- "nothing to record: ..." message; the failure detail otherwise
local function save(s: store.Store, it: item.Item, message: string,
    spec?: itemtree.Spec, also?: {item.Item}): boolean, string
  local refusal = storeinit.linked_worktree_refusal(s.root)
  if refusal ~= nil then
    return false, refusal
  end
  local current, ferr = format.require_current(s.root)
  if not current then
    return false, ferr
  end
  return statewrite.save(s, it, message, spec, also)
end

local record storewrite
  set_session: function(s: store.Store, session: string)
  set_op: function(s: store.Store, op: string)
  set_bounded: function(s: store.Store, bounded: boolean)
  save: function(s: store.Store, it: item.Item, message: string,
  spec?: itemtree.Spec, also?: {item.Item}): boolean, string
end

local M: storewrite = {
  set_session = set_session,
  set_op = set_op,
  set_bounded = set_bounded,
  save = save,
}

return M
