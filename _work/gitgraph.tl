--- The graph verbs: `new` and `attach` — the mutations that shape the
--- item GRAPH (an item's existence, a parent edge) rather than moving
--- work state, which is `_work.gitverbs`. `set` lives here too: not a
--- graph edge, but the other class of fact nothing else moves — an
--- item's own destination (`title`, `repo`, `base`), fixed at file
--- time and otherwise stuck once a refinement outgrows it.
---
--- Verbs receive FULL ids — the dispatcher
--- resolves prefixes — and every verb prints a `gitboard-<verb>:`
--- verdict line and returns its exit code. Mutations commit locally
--- and publish through `publish.publish`, whose rejected-push path
--- drops the mutation whole, re-syncs, and refuses — re-running the
--- verb re-applies every gate against the merged board.
---
--- Decomposition and re-triage are both `attach`: moving an item's
--- parent is the whole operation, because roles derive from the
--- graph — an outcome becomes work by gaining a parent other than the
--- board, and a workable item becomes a container the moment a child
--- attaches under it. Rank is the other half of triage and has its
--- own verb, `rank`, because an item can be placed without being
--- moved and moved without being ranked. `new` with no `--parent`
--- files under the board — the one parentless item — the same
--- position `attach` never needs to move an item TO, since only
--- `init` creates it.
local cachequery = require("_work.cachequery")
local friction = require("_work.gitfriction")
local gate = require("_work.gitgate")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local owner = require("_work.gitowner")
local rank = require("_work.gitrank")
local read = require("_work.read")
local session = require("_work.session")
local store = require("_work.store")

--- Add `x` to `list` unless some entry already shares its id — the
--- merge `cmd_new`/`cmd_attach` use to fold a parent placement
--- mutated into `also` alongside whatever `gate.containered` already
--- put there, without writing the same item twice in one commit.
--- @param list {item.Item} The items a mutation already writes
--- @param x item.Item The item to add
--- @return {item.Item} `list`, mutated in place and returned
local function add_once(list: {item.Item}, x: item.Item): {item.Item}
  for _, y in ipairs(list) do
    if y.id == x.id then
      return list
    end
  end
  list[#list + 1] = x
  return list
end

--- File a new item into the graph, todo if it lands below the outcome
--- level, triage if it lands directly under the board. `spec` is nil
--- to leave the tree with no `spec.md` at all — an empty string would
--- instead write an EMPTY `spec.md`, which is a different, visible
--- outcome. Mints a fresh id; a caller that needs a chosen id (a
--- fixture, a replay) builds the `item.Item` and calls
--- `storewrite.save` directly — see `_work/storeinit_test.tl`'s
--- `seed_one_item`.
--- @param s store.Store The store
--- @param title string The item's title
--- @param parent string The parent id, or "" to file it under the
--- board — refused when this repository has no board yet (`init`
--- creates one)
--- @param spec string | nil Sidecar prose to write, or nil to write none
--- @param repo string The item's repo field; nil becomes "". Refused
--- under a foreign owner unless `spec` names it under `## Access`
--- @param force boolean | nil File a `friction:` item over an incomplete
--- roll call — a pass whose transcripts are gone
--- @param why string | nil Why --force was needed
--- @param before string | nil Place it immediately before this sibling
--- under `parent` (the board, when `parent` is "")
--- @param after string | nil Place it immediately after this sibling
--- under `parent`; at most one of before/after
--- @return integer 0 on success, 1 otherwise
local function cmd_new(s: store.Store, title: string, parent: string,
    spec: string | nil, repo: string, force?: boolean, why?: string,
    before?: string, after?: string): integer
  local frc = force or false
  local rsn = why or ""
  local bfr = before or ""
  local aft = after or ""
  local forced = gate.force_refusal(frc, rsn)
  if forced then
    return gate.verdict_line("new", false, "REFUSED: " .. forced)
  end
  -- A friction log names every agent this session claimed work under
  -- since the pass began, or the filing is refused: the only thing
  -- that used to distinguish a full roll call from an empty one was
  -- prose, and nothing refused the thinner log. `new` carries no
  -- `--session` flag — unlike `take`/`drop`/`spec`/`verdict` — so this
  -- resolved identity is for the friction check alone, never for
  -- commit authorship: every `new` commits under the tool identity.
  -- Listed once, before the friction check below: `store.list` is
  -- what populates `s`'s per-item lease (`leased_sha`), which is what
  -- lets `friction.friction_refusal` batch its past-filing spec reads
  -- through `store.read_specs` instead of one `read_spec` per filing.
  local all, aerr = store.list(s)
  if all == nil then
    return gate.verdict_line("new", false, aerr)
  end
  if not frc and title:sub(1, 9) == "friction:" then
    local refusal = friction.friction_refusal(s, session.resolve(nil), spec or "")
    if refusal then
      return gate.verdict_line("new", false, refusal)
    end
  end
  local index = item.by_id(all)
  local c, cerr = store.read(s)
  if c == nil then
    return gate.verdict_line("new", false, cerr)
  end
  -- No `--parent` means "under the board" — found as the one
  -- parentless item, never a second field to keep in step with it.
  local parent_id = parent
  if parent_id == "" then
    local board_id, berr = read.board(c)
    if board_id == nil then
      if berr ~= "" then
        return gate.verdict_line("new", false, berr)
      end
      return gate.verdict_line("new", false,
        "REFUSED: this board has no board item yet — run `gitboard init`")
    end
    parent_id = board_id
  end
  local parent_item = index[parent_id]
  if parent_item == nil then
    return gate.verdict_line("new", false, ("no item %s"):format(parent_id))
  end
  local parent_role, prerr = read.role(c, parent_item.id)
  if parent_role == nil then
    return gate.verdict_line("new", false, prerr)
  end
  local it: item.Item = {
    id = ksuid.new(), title = title, parent = parent_id, repo = repo or "",
    order = {}, claim = "", pr = 0, verdict = "",
    verdict_head = "", resolution = "",
  }
  local bad = item.problems(it)
  if #bad > 0 then
    return gate.verdict_line("new", false, table.concat(bad, "; "))
  end
  -- The owner rule binds at the write, so a foreign `repo` never
  -- enters the board: the spec being filed alongside is where an
  -- `## Access` escape would be read from.
  local foreign = owner.repo_problem(s, it.repo, spec or "", "")
  if foreign then
    return gate.verdict_line("new", false, "REFUSED: " .. foreign)
  end
  -- Warning only, never a refusal — printed before the mint verdict so
  -- a session sees a likely duplicate before it commits to a new id.
  -- `s.board_digest` is the snapshot `store.list` above already took —
  -- passed through so this open never re-reads it fresh.
  for _, line in ipairs(cachequery.similar_lines(s.root, title, s.board_digest)) do
    print(line)
  end
  -- No gate: a filed child always enters `todo`, which is unbounded
  -- by design — the queue intake writes into can always accept,
  -- which is what keeps the cheap decision cheap. The bound binds at
  -- take, where committing to work is the expensive decision.
  local also, coerr = gate.containered(c, parent_item)
  if also == nil then
    return gate.verdict_line("new", false, coerr)
  end
  if bfr ~= "" or aft ~= "" then
    local placed, perr = rank.place_under(parent_item, it.id, bfr, aft, index)
    if not placed then
      return gate.verdict_line("new", false, perr)
    end
    also = add_once(also, parent_item)
  end
  local ok, err = gate.commit_and_publish(s, it, spec,
    ("new %s %s%s"):format(it.id:sub(1, 8), title, gate.forced_suffix(frc, rsn)),
    "new", also)
  if not ok then
    return gate.verdict_line("new", false, err)
  end
  local entered = "todo"
  if parent_role == "board" then
    entered = "triage — rank it among the outcomes, or attach it under a "
    .. "ranked outcome"
  end
  return gate.verdict_line("new", true, ("%s enters %s"):format(it.id, entered))
end

--- Give an item a parent, moving it from triage into todo. Refuses a
--- self-parent, a missing id on either side, and a parent whose own
--- chain would cycle back to the item being attached. `before`/`after`
--- place it among its new siblings in the same commit — X must
--- already be a positioned child of `parent`, the same rule `rank`
--- itself enforces; the item's position under whatever parent it is
--- LEAVING is never rewritten, and stays meaningless there once it
--- has left.
--- @param s store.Store The store
--- @param id string The item gaining a parent
--- @param parent string The new parent id
--- @param before string | nil Place it immediately before this sibling
--- @param after string | nil Place it immediately after this sibling;
--- at most one of before/after
--- @return integer 0 on success, 1 otherwise
local function cmd_attach(s: store.Store, id: string, parent: string,
    before?: string, after?: string): integer
  local all, aerr = store.list(s)
  if all == nil then
    return gate.verdict_line("attach", false, aerr)
  end
  local index = item.by_id(all)
  local it = index[id]
  local parent_item = index[parent]
  if it == nil then
    return gate.verdict_line("attach", false, ("no item %s"):format(id))
  end
  if parent_item == nil then
    return gate.verdict_line("attach", false, ("no item %s"):format(parent))
  end
  if id == parent then
    return gate.verdict_line("attach", false, "an item cannot parent itself")
  end
  local c, cerr = store.read(s)
  if c == nil then
    return gate.verdict_line("attach", false, cerr)
  end
  local reaches, rberr = read.reaches_board(c, parent_item.id)
  if reaches == nil then
    return gate.verdict_line("attach", false, rberr)
  end
  if not reaches then
    return gate.verdict_line("attach", false,
      ("%s's own parent chain is broken"):format(parent:sub(1, 8)))
  end
  local cur = parent_item
  while cur ~= nil do
    if cur.id == id then
      return gate.verdict_line("attach", false,
        ("attaching under %s would make a cycle"):format(parent:sub(1, 8)))
    end
    cur = index[cur.parent or ""]
  end
  it.parent = parent
  -- Adoption makes a leaf workable: it is todo by derivation, with
  -- nothing to write. Triage answers one cheap question — is this
  -- real, and under which outcome — and placing an item is not
  -- committing to build it; the expensive decision is the take, where
  -- the spec bar and the doing bound bind.
  local bad = item.problems(it)
  if #bad > 0 then
    return gate.verdict_line("attach", false, table.concat(bad, "; "))
  end
  local also, coerr = gate.containered(c, parent_item)
  if also == nil then
    return gate.verdict_line("attach", false, coerr)
  end
  if (before or "") ~= "" or (after or "") ~= "" then
    local placed, perr = rank.place_under(parent_item, id, before or "",
      after or "", index)
    if not placed then
      return gate.verdict_line("attach", false, perr)
    end
    also = add_once(also, parent_item)
  end
  local ok, err = gate.commit_and_publish(s, it, nil,
    ("attach %s under %s"):format(id:sub(1, 8), parent:sub(1, 8)),
    "attach", also)
  if not ok then
    return gate.verdict_line("attach", false, err)
  end
  if store.is_noop(err) then
    return gate.verdict_line("attach", true, err)
  end
  -- `commit_and_publish` closed the connection `c` came from — a fresh
  -- one, opened here, is what the post-mutation role check reads.
  local workable = ""
  local after_c, cerr2 = store.read(s)
  if after_c == nil then
    return gate.verdict_line("attach", false, cerr2)
  end
  local role, roerr = read.role(after_c, id)
  if role == nil then
    return gate.verdict_line("attach", false, roerr)
  end
  if role ~= "container" then
    workable = " — workable, in todo"
  end
  return gate.verdict_line("attach", true,
    ("%s now under %s%s"):format(id:sub(1, 8), parent:sub(1, 8), workable))
end

--- set: repair one of the three destination-fact fields directly —
--- `title`, `repo`, `base` — the fields no other verb moves once an
--- item is filed. Flow fields (claim, pr, verdict, resolution, parent,
--- key) have their own verbs and gates; `set` refuses
--- them by not existing for them — the dispatcher's flag spec never
--- declares those long names on this command, so passing one is an
--- unrecognized-flag refusal before `set` is ever called.
---
--- Every passed field lands in canonical order (title, repo, base)
--- regardless of flag order, so the commit subject — `set <id8>
--- <field>...` — is deterministic and names only WHICH fields moved;
--- the values ride in the diff, not the subject, because a title is
--- long and a diff already shows what changed.
--- @param s store.Store The store
--- @param id string The item to repair
--- @param title string | nil The new title, nil to leave it unchanged
--- @param repo string | nil The new repo, nil to leave it unchanged
--- @param new_base string | nil The new base branch, nil to leave it unchanged
--- @return integer Exit code
local function cmd_set(s: store.Store, id: string, title: string | nil,
    repo: string | nil, new_base: string | nil): integer
  if title == nil and repo == nil and new_base == nil then
    return gate.verdict_line("set", false,
      "REFUSED: set needs at least one of --title, --repo, --base")
  end
  local it, lerr = store.load(s, id)
  if it == nil then
    return gate.verdict_line("set", false, lerr)
  end
  if not item.is_open(it) then
    return gate.verdict_line("set", false,
      ("REFUSED: %s is done (%s) — a finished item's facts are history, "
        .. "not a repair target"):format(id:sub(1, 8), it.resolution))
  end
  local fields: {string} = {}
  if title ~= nil then
    if title:match("%S") == nil then
      return gate.verdict_line("set", false, "REFUSED: --title cannot be empty")
    end
    it.title = title
    fields[#fields + 1] = "title"
  end
  if repo ~= nil then
    if repo:match("%S") == nil then
      return gate.verdict_line("set", false,
        "REFUSED: --repo cannot be empty — clearing it is not supported; "
        .. "set --repo <owner>/<name> to change it")
    end
    local foreign = owner.repo_problem(s, repo, store.read_spec(s, id), id)
    if foreign then
      return gate.verdict_line("set", false, "REFUSED: " .. foreign)
    end
    it.repo = repo
    fields[#fields + 1] = "repo"
  end
  if new_base ~= nil then
    if new_base:match("%S") == nil then
      return gate.verdict_line("set", false,
        "REFUSED: --base cannot be empty — clearing it is not supported; "
        .. "set --base <branch> to change it")
    end
    it.base = new_base
    fields[#fields + 1] = "base"
  end
  local bad = item.problems(it)
  if #bad > 0 then
    return gate.verdict_line("set", false, table.concat(bad, "; "))
  end
  local ok, err = gate.commit_and_publish(s, it, nil,
    ("set %s %s"):format(id:sub(1, 8), table.concat(fields, " ")), "set")
  if not ok then
    return gate.verdict_line("set", false, err)
  end
  if store.is_noop(err) then
    return gate.verdict_line("set", true, err)
  end
  return gate.verdict_line("set", true,
    ("%s: %s updated"):format(id:sub(1, 8), table.concat(fields, ", ")))
end

local record gitgraph
  cmd_new: function(s: store.Store, title: string, parent: string,
  spec: string | nil, repo: string, force?: boolean, why?: string,
  before?: string, after?: string): integer
  cmd_attach: function(s: store.Store, id: string, parent: string,
  before?: string, after?: string): integer
  cmd_set: function(s: store.Store, id: string, title: string | nil,
  repo: string | nil, new_base: string | nil): integer
end

local M: gitgraph = {
  cmd_new = cmd_new,
  cmd_attach = cmd_attach,
  cmd_set = cmd_set,
}

return M
