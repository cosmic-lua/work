--- The item store: every item lives as a git ref — `refs/heads/items/<id>` for an ordinary
--- item, `refs/heads/ended/<id>` for one resolved before this rule (`ended/` is legacy:
--- read, never written) — whose tip commit's tree is the item's current state
--- (`_work.itemtree`'s canonical shape) and whose parent chain is its history. A resolution
--- sets `resolution` on whichever ref the item already lives on; it never moves the ref.
--- There is no working tree to hold them: `open` needs only a git repository, and a
--- mutation writes git objects and updates refs directly, never a file. Publishing that to
--- a remote, and reading the log back, live in `_work.publish`, which calls back into
--- `git`/`git_ok` here for the same deterministic tool identity every store call uses.
---
--- The read and write mechanics are `_work.gitread`/`_work.gitwrite`, split out to keep
--- this file under its line cap; this module is the read half — opening a repository,
--- resolving an id prefix, and loading or listing items. The write half — `save`,
--- `add_pending`, and the lease/CAS bookkeeping (`set_session`/`set_op`/`set_bounded`) a
--- verb sets before calling `save` — is `_work.storewrite`, split out the same way and for
--- the same reason; it requires this module for the `Store` type and the few pieces of
--- state (`NOOP_PREFIX`, `snapshot_item`, `stage`, `read_spec`) its own `save` needs, so
--- this module never requires it back.
local child = require("cosmic.child")
local format = require("_work.format")
local fs = require("cosmic.fs")
local gitread = require("_work.gitread")
local item = require("_work.item")
local refs = require("_work.refs")

--- One open state repository. Every field but `root` is working state
--- a single verb invocation accumulates: the session and `Op:` trailer the next `save`
--- should credit, whether it is bounded, the lease (ref + tip) each id was last observed
--- at, a SNAPSHOT of each id's item as observed (`leased_item` — independent of whatever a
--- caller goes on to mutate `load`'s/`list`'s own returned `item.Item` into, since `save`'s
--- fast-import diff needs the ORIGINAL fields to compare against), `refs/heads/board/seq`'s
--- own observed tip, the refs a completed `save` still owes `publish` a push for, and every
--- id the most recent `list` found filed under both `refs/heads/items` and
--- `refs/heads/ended` at once (`gitread.Duplicate` — `fsck` is the only reader; `list`'s
--- ref-snapshot digest, and `resolve`'s and `list`'s own one-shot leases, live here too).
--- Declared here, alongside the read half, since `_work.storewrite`'s `save` mutates the
--- same fields this module's `load`/`list` populate.
---
--- `remote_url`/`remote_present` are a second memo, of the two ad hoc
--- git facts `_work.gh.slug` and `_work.publish.has_origin` each read
--- with their own process: `git remote get-url origin` and `git
--- remote`, neither of which changes within one run, so the first read
--- of each is the only one that ever has to happen — the `_read` flags
--- distinguish "not asked yet" from "asked, and the answer was empty
--- or an error," which an empty string alone cannot.
local record Store
  root: string
  session: string
  op: string
  bounded: boolean
  leased_ref: {string: string}
  leased_sha: {string: string}
  leased_item: {string: item.Item}
  observed_seq: string
  pending: {refs.PushSpec}
  duplicates: {gitread.Duplicate}
  board_digest: string
  fresh_lease: string
  remote_url: string
  remote_url_ok: boolean
  remote_url_read: boolean
  remote_present: boolean
  remote_present_read: boolean
end

--- The refusal a lost push race earns, exported so a verb can tell it
--- from a terminal failure; compared by identity, never matched.
local LOST_RACE < const > = "lost the push race — the mutation was dropped "
.. "whole and the checkout re-synced; re-run the verb against the "
.. "current board"

--- The fixed prefix a no-op `save` carries, so `is_noop` can tell one
--- from an ordinary success or a terminal failure without matching
--- the whole message.
local NOOP_PREFIX < const > = "nothing to record: "

--- Whether an outcome from `save` (or a caller built on it, like
--- `_work.gitgate.commit_and_publish`) is the no-op success.
--- @param detail string The message returned alongside a truthy `save`
--- @return boolean True on a no-op success
local function is_noop(detail: string): boolean
  return (detail or ""):sub(1, #NOOP_PREFIX) == NOOP_PREFIX
end

--- Git defaults for the ad hoc commands this module and `_work.publish`
--- still run directly (`remote`, `push`, `fetch`, ...): a deterministic
--- identity for anything that happens to create an object, and
--- rename-based object finalization — link-based finalization fails
--- with EXDEV on the overlay/bind mounts CI containers run tests on.
local GIT_DEFAULTS: {string} = {
  "-c", "user.email=noreply@anthropic.com", "-c", "user.name=Claude",
  "-c", "core.createObject=rename",
}

--- Run one git command in the store's root.
--- @param s Store The store
--- @param argv {string} Arguments after "git"
--- @return child.Result | nil The finished run, whatever its exit
--- @return string Error message when git could not be started
local function git(s: Store, argv: {string}): child.Result | nil, string
  local full: {string} = {"git"}
  for _, a in ipairs(GIT_DEFAULTS) do
    full[#full + 1] = a
  end
  for _, a in ipairs(argv) do
    full[#full + 1] = a
  end
  return child.run(full, {cwd = s.root})
end

--- Run one git command that must succeed.
--- @param s Store The store
--- @param argv {string} Arguments after "git"
--- @return child.Result | nil The zero-exit run
--- @return string Error message naming the command and its stderr
local function git_ok(s: Store, argv: {string}): child.Result | nil, string
  local r, err = git(s, argv)
  if r == nil then
    return nil, err
  end
  if not r.ok then
    local detail = (r.stderr or ""):gsub("%s+$", "")
    if detail == "" then
      detail = (r.stdout or ""):gsub("%s+$", "")
    end
    return nil, ("git %s failed: %s"):format(table.concat(argv, " "), detail)
  end
  return r
end

--- Create a state repository at `dir`: a git repository (initialized
--- when none is there yet), with the mirror refspecs ADDED to
--- `remote.origin.fetch` (`refs.ensure_refspecs`; `sync` adds them too,
--- so a plain clone needs no `init` to read the board), and `refs/heads/board/format` created (and
--- best-effort pushed) when this repository has none yet
--- (`format.ensure`). `git clone` already gave `origin` its own
--- default refspec for the checked-out branch (how the machinery
--- itself stays pullable) — this only adds the three item-ref
--- patterns beside it, never replacing what was there, so a plain
--- `git pull` on the branch keeps working. There is no `items/`
--- directory to create — every item lives as a ref, not a file — so a
--- fresh repository with nothing filed yet needs nothing else here.
--- @param dir string The directory to prepare
--- @return boolean True on success
--- @return string Error message
local function init_repo(dir: string): boolean, string
  if not fs.is_dir(fs.join(dir, ".git")) then
    local r, err = child.run({"git", "init", "-q", dir})
    if r == nil or not r.ok then
      return false, err or (r and r.stderr) or "git init failed"
    end
  end
  local specs_ok, serr = refs.ensure_refspecs(dir)
  if not specs_ok then
    return false, serr
  end
  local ensured, eerr = format.ensure(dir)
  if not ensured then
    return false, eerr
  end
  return true
end

--- Open a state repository checkout. The root must be a git
--- repository — `gitboard init` (`init_repo`) creates one.
--- @param root string Checkout root
--- @return Store | nil The store
--- @return string Error message
local function open(root: string): Store | nil, string
  if not fs.is_present(fs.join(root, ".git")) then
    return nil, ("not a git repository: %s"):format(root)
  end
  return {root = root, session = "", op = "", bounded = false, leased_ref = {},
    leased_sha = {}, leased_item = {}, observed_seq = "", pending = {}, duplicates = {},
    board_digest = "", fresh_lease = "", remote_url = "", remote_url_ok = false,
    remote_url_read = false, remote_present = false, remote_present_read = false}
end

--- The full id a unique prefix names, resolved against the refs
--- directly — `for-each-ref` treats a full ref name as a pattern that
--- also matches any glob suffixed onto it, so one call covers both an
--- exact id and a genuine prefix.
--- @param s Store The store
--- @param prefix string An id or a prefix of one
--- @return string | nil The full id
--- @return string Error message: nothing matched, or the matches
local function resolve(s: Store, prefix: string): string | nil, string
  if prefix == nil or prefix == "" or prefix:match("^%w+$") == nil then
    return nil, ("not an id prefix: %s"):format(tostring(prefix))
  end
  local found, ferr = refs.for_each_ref(s.root,
    {"refs/heads/items/" .. prefix .. "*", "refs/heads/ended/" .. prefix .. "*"})
  if found == nil then
    return nil, ferr
  end
  local matches: {string} = {}
  local seen: {string: boolean} = {}
  for _, r in ipairs(found) do
    local id = r.refname:match("^refs/heads/items/(.+)$") or r.refname:match("^refs/heads/ended/(.+)$")
    if id and not seen[id] then
      seen[id] = true
      matches[#matches + 1] = id
    end
  end
  if #matches == 0 then
    return nil, ("no item matches %s"):format(prefix)
  end
  if #matches > 1 then
    return nil, ("%s is ambiguous: %s"):format(prefix, table.concat(matches, " "))
  end
  if #found == 1 then -- never the ambiguous case; see the Store doc
    s.fresh_lease = gitread.lease_encode(matches[1], found[1].refname, found[1].sha)
  end
  return matches[1]
end

--- An item's spec sidecar, "" when it has none.
--- @param s Store The store
--- @param id string Item id
--- @return string The spec markdown, possibly empty
local function read_spec(s: Store, id: string): string
  local ref = s.leased_ref[id]
  if ref ~= nil then
    return gitread.read_spec(s.root, {ref})
  end
  return gitread.read_spec(s.root, {"refs/heads/items/" .. id, "refs/heads/ended/" .. id})
end

--- Every named item's spec sidecar in one batch, "" for one with
--- none — the whole-board counterpart to `read_spec`; used for a
--- readiness pass over many items instead of one process each. Reads
--- against `s.leased_sha`, so call `list` (or `load` each id) first.
--- @param s Store The store
--- @param ids {string} Item ids to read, in any order
--- @return {string: string} Spec markdown by id, possibly empty
local function read_specs(s: Store, ids: {string}): {string: string}
  return gitread.read_specs(s.root, s.leased_sha, ids)
end

--- An independent copy of `it`, sharing no table with it — `encode`
--- then `decode` round-trips through fresh tables at every level
--- (`_work.item`'s own tested inverse pair), so this is cheaper to
--- lean on than a bespoke deep-copy function. Used here to snapshot an
--- item as OBSERVED, before any caller goes on to mutate the object
--- `load`/`list` handed back — `decode`'s own tolerance means this can
--- only fail on an item already flagged unreadable, in which case the
--- snapshot is skipped rather than surfaced as an error: the
--- fast-import diff (`_work.fastimport.diff_item`) treats a missing
--- snapshot as "unobserved", which only costs it writing every path
--- unconditionally for that one item, never a wrong answer. Exported
--- for `_work.storewrite.save` to snapshot what it just wrote, into
--- the same `leased_item` table this module populates.
--- @param it item.Item The item to copy
--- @return item.Item | nil The copy, nil when re-decoding it failed
local function snapshot_item(it: item.Item): item.Item | nil
  local copy, _err = item.decode(item.encode(it))
  return copy
end

--- Load one item, remembering its ref and tip as the lease `save`
--- writes against next, and a snapshot of its fields as observed —
--- the baseline `save`'s fast-import diff compares the mutated item
--- against — `resolve`'s one-shot lease for this id, when it just set one.
--- @param s Store The store
--- @param id string Item id
--- @return item.Item | nil The item
--- @return string Error message; "no item <id>" when absent
local function load_item(s: Store, id: string): item.Item | nil, string
  local ref, sha = gitread.lease_decode(s.fresh_lease, id)
  s.fresh_lease = ""
  local loaded, err = gitread.load(s.root, id, ref, sha)
  if loaded == nil then
    return nil, err
  end
  s.leased_ref[id], s.leased_sha[id] = loaded.ref, loaded.sha
  s.leased_item[id] = snapshot_item(loaded.it)
  return loaded.it
end

--- Every item in the store, done ones included, sorted by id. Three
--- git processes for the whole board, whatever its size — never one
--- per item; see `_work.gitread.list`.
--- @param s Store The store
--- @return {item.Item} | nil The items, some possibly flagged
--- @return string Error message naming the first genuinely corrupt item
local function list(s: Store): {item.Item} | nil, string
  local board, err = gitread.list(s.root)
  if board == nil then
    return nil, err
  end
  for id, ref in pairs(board.refs_by_id) do
    s.leased_ref[id] = ref
    s.leased_sha[id] = board.shas_by_id[id]
  end
  for _, it in ipairs(board.items) do
    s.leased_item[it.id] = snapshot_item(it)
  end
  s.observed_seq = board.seq_sha
  s.duplicates = board.duplicates
  s.board_digest = board.refs_digest
  return board.items
end

--- Every id the most recent `list` found filed under both
--- `refs/heads/items` and `refs/heads/ended` at once — empty before
--- the first `list` call, or on a board with none. `_work.gitfsck` is
--- the only caller: every other verb just uses whichever ref `list`
--- already picked as the lease.
--- @param s Store The store
--- @return {gitread.Duplicate} The duplicates `list` found, possibly empty
local function duplicates(s: Store): {gitread.Duplicate}
  return s.duplicates
end

--- One line summarizing every item `list` flagged, in list order; ""
--- when nothing was.
--- @param items {item.Item} Items from `list`
--- @return string "N unreadable/flagged: <id8> — <reason>[; ...]", or ""
local function flagged_summary(items: {item.Item}): string
  local parts: {string} = {}
  for _, it in ipairs(items) do
    if item.is_flagged(it) then
      parts[#parts + 1] = ("%s — %s"):format(it.id:sub(1, 8),
        table.concat(it.decode_problems or {}, ", "))
    end
  end
  if #parts == 0 then
    return ""
  end
  return ("%d unreadable/flagged: %s"):format(#parts, table.concat(parts, "; "))
end

--- Validate an item well enough to write. `_work.storewrite.save` calls
--- this itself for `it` and every `also` item before touching any
--- object; kept as its own function since it is also how a caller
--- checks a hand-built record without writing it.
--- @param s Store The store
--- @param it item.Item The item
--- @param _spec string | nil Unused; kept for signature compatibility
--- @return boolean True when the item may be written
--- @return string Error message
local function stage(_s: Store, it: item.Item, _spec?: string): boolean, string
  local bad = item.problems(it)
  if #bad > 0 then
    return false, table.concat(bad, "; ")
  end
  return true, ""
end

local record store
  type Store = Store
  LOST_RACE: string
  NOOP_PREFIX: string
  is_noop: function(detail: string): boolean
  git: function(s: Store, argv: {string}): child.Result | nil, string
  git_ok: function(s: Store, argv: {string}): child.Result | nil, string
  init_repo: function(dir: string): boolean, string
  open: function(root: string): Store | nil, string
  load: function(s: Store, id: string): item.Item | nil, string
  resolve: function(s: Store, prefix: string): string | nil, string
  read_spec: function(s: Store, id: string): string
  read_specs: function(s: Store, ids: {string}): {string: string}
  snapshot_item: function(it: item.Item): item.Item | nil
  list: function(s: Store): {item.Item} | nil, string
  duplicates: function(s: Store): {gitread.Duplicate}
  flagged_summary: function(items: {item.Item}): string
  stage: function(s: Store, it: item.Item, spec?: string): boolean, string
end

local M: store = {
  LOST_RACE = LOST_RACE,
  NOOP_PREFIX = NOOP_PREFIX,
  is_noop = is_noop,
  git = git,
  git_ok = git_ok,
  init_repo = init_repo,
  open = open,
  load = load_item,
  resolve = resolve,
  read_spec = read_spec,
  read_specs = read_specs,
  snapshot_item = snapshot_item,
  list = list,
  duplicates = duplicates,
  flagged_summary = flagged_summary,
  stage = stage,
}

return M
