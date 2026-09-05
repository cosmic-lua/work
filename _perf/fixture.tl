--- A synthetic gitboard fixture for `_perf/bench/verbs_bench.tl`: a local
--- bare "origin" plus a ready clone, filed with deterministic items so two
--- runs measure the same board — never the network, never the live board.
---
--- Every item is written straight through `_work.item`/`_work.store`
--- (the same object model every verb reads and writes), never through
--- `o/bin/gitboard` itself: minting a thousand items through the CLI would
--- spawn a thousand processes before a single scenario timed anything.
--- Ids are KSUIDs built from a fixed epoch second and an index-derived
--- 16-byte payload (`ksuid.encode`, the same constructor `ksuid.new` uses,
--- with the CSPRNG payload replaced by one that is a pure function of the
--- index) — so `build(n)` yields byte-identical ids, titles and specs on
--- every call for the same `n`, on every machine.
---
--- The shape mirrors the live board, not just its size. Measured
--- 2026-09-04 against a local clone of cosmic-lua/work carrying the real
--- board (920 item refs: 197 `refs/heads/items` + 723 `refs/heads/ended`),
--- by walking every item ref's tree:
---
---   for ref in $(git for-each-ref --format='%(refname)' \
---       refs/heads/items refs/heads/ended); do
---     git ls-tree -r --name-only "$ref^{tree}"    # parent/spec.md/edges/*
---     git cat-file -p "$ref:meta"                 # resolution:
---   done
---
--- gave: 873/920 (95%) carry a `parent` (workable leaves; the rest are
--- roots), 727/920 (79%) carry a `resolution` (done), 76/920 (8.3%) hold
--- at least one outgoing `beats` edge (a comparison's winner — most
--- comparisons are roots placed against a peer), 172/920 (19%) carry a
--- `blocked_by` edge, and every item (920/920) carries a `spec.md`. The
--- ratios below are those measurements; `build` reproduces them, not the
--- literal counts, so they hold at any `n`.
local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local item = require("_work.item")
local ksuid = require("_work.ksuid")
local publish = require("_work.publish")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local N_DEFAULT < const > = 1000
local MIN_N < const > = 8
local PARENT_RATIO < const > = 0.95
local RESOLVED_RATIO < const > = 0.79
local BEATS_WINNER_RATIO < const > = 0.083
local BLOCKED_RATIO < const > = 0.19
--- Open, unclaimed, PR-less leaves reserved for `_perf/bench/verbs_bench.tl`'s
--- `done` scenario to consume one per timed call — sized comfortably above
--- what the harness's default calibration ever spends on one scenario
--- (warm-up + calibration probe + samples + the allocation probe, each at
--- one call when a `done` round-trip clears `min_sample_secs` in one go).
local DONE_POOL_SIZE < const > = 96
--- KSUID's own epoch (`_work.ksuid`) plus a fixed offset, so a payload of
--- all zero bytes never collides with a real, live-board id (whose payload
--- is 16 CSPRNG bytes — astronomically unlikely to be zero, but this
--- keeps `build`'s ids visibly synthetic even if it were).
local EPOCH_SECONDS < const > = 1700000000

local FIXTURE_SPEC < const > = [[
## Change
Fixture item for the gitboard perf scenarios: no real change.
## Non-goals
Real work; this item is never taken.
]]

--- One item's id: a KSUID whose payload is a pure function of `i`, so it
--- never collides across items and never changes between builds.
--- @param i integer 1-based item index
--- @return string The 27-character id
local function mint_id(i: integer): string
  return check.must(ksuid.encode(EPOCH_SECONDS, string.pack(">I8I8", 0, i)))
end

--- Round to the nearest integer, ties away from zero — good enough for
--- sizing groups from a ratio; the exact boundary never matters here.
--- @param x number
--- @return integer
local function round(x: number): integer
  return math.floor(x + 0.5)
end

--- The empty, ambient-free git identity every fixture git call runs
--- under: a build under the sandbox fence has no `$HOME` to read
--- `~/.gitconfig` from, and git treats a config it cannot READ as fatal,
--- not absent.
--- @param tmp_base string A writable scratch directory
local function hermetic_git_env(tmp_base: string)
  local cfg = fs.join(tmp_base, "gitboard-perf-gitconfig-empty")
  assert(fs.write(cfg, ""))
  assert(env.set("GIT_CONFIG_GLOBAL", cfg))
  assert(env.set("GIT_CONFIG_NOSYSTEM", "1"))
end

--- Run one git command in `cwd`, failing loudly — fixture plumbing, never
--- the code a scenario measures.
--- @param cwd string
--- @param argv {string}
local function git(cwd: string, argv: {string})
  local full: {string} = {"git"}
  for _, a in ipairs(argv) do
    full[#full + 1] = a
  end
  local r = check.must(child.run(full, {cwd = cwd}))
  assert(r.ok, "git " .. table.concat(argv, " ") .. " failed: " .. r.stderr)
end

--- A fresh clone of `bare` at `dest`, with the mirror refspecs a real
--- `gitboard init` (`store.init_repo`) would add — every scenario that
--- mutates gets its OWN such clone from `setup`, so one scenario's
--- writes are never the residue another scenario's `fn` reads. `git
--- clone` alone only populates `refs/remotes/origin/*`; a plain
--- `gitboard init` right after it adds the mirror refspecs but fetches
--- nothing on its own (by design — a truly fresh board has nothing to
--- fetch), so this also runs the one sync a real session would run
--- before its first verb against a clone of an already-populated board.
--- @param bare string The bare origin
--- @param dest string Where to clone it; removed first if present
--- @return string The clone's path
--- @return string Error message on failure
local function fresh_clone(bare: string, dest: string): string, string
  assert(fs.remove_all(dest))
  git(fs.dirname(dest), {"clone", "-q", bare, dest})
  git(dest, {"config", "core.createObject", "rename"})
  local iok, ierr = store.init_repo(dest)
  if not iok then
    return nil, "init_repo: " .. ierr
  end
  local s, serr = store.open(dest)
  if s == nil then
    return nil, serr
  end
  local sok, syerr = publish.sync(s)
  if not sok then
    return nil, "sync: " .. syerr
  end
  return dest
end

--- A built fixture: the bare origin every scenario's mutations eventually
--- land on, a ready clone for the read-only scenarios, and the ids a
--- scenario needs to name a target without walking the board first.
local record Fixture
  --- The scratch directory holding everything below; `cleanup()` removes
  --- exactly this.
  root: string
  --- The bare "origin" — `git clone`'s source for every fresh clone a
  --- mutating scenario's `setup` makes.
  bare: string
  --- A ready clone of `bare`, already synced — what the read-only
  --- scenarios (`show`, `next`, `find`, `fsck`, `sync`) point `GITBOARD_DIR`
  --- at directly, no cloning of their own.
  clone: string
  n: integer
  --- An existing root, always open: `show ID`'s target and `new`'s
  --- `--parent`.
  sample_id: string
  --- `compare`'s winner and loser — two roots the fixture already placed
  --- against each other, so the scenario's repeated calls re-record the
  --- SAME judgment (a no-op after the first, exactly as re-running a real
  --- `compare` does).
  compare_winner: string
  compare_loser: string
  --- Open, unclaimed, PR-less leaves `done` may resolve one at a time.
  done_pool: {string}
end

--- Build a synthetic board of `n` items (env `GITBOARD_PERF_N` when `n` is
--- omitted, else 1000) in a fresh local bare origin plus a clone, in the
--- proportions this file's header measured. Every item is written
--- directly through `_work.store` and pushed once, in one batch, at the
--- end — never through `o/bin/gitboard`, and never over a network.
--- @param n integer? Item count; overrides `GITBOARD_PERF_N` and the default
--- @return Fixture
--- @return string Error message on failure
local function build(n?: integer): Fixture, string
  local total = n
  if total == nil then
    total = math.tointeger(tonumber(os.getenv("GITBOARD_PERF_N") or "")) or N_DEFAULT
  end
  if total < MIN_N then
    total = MIN_N
  end

  local num_roots = math.max(2, round(total * (1 - PARENT_RATIO)))
  if num_roots >= total then
    num_roots = total - 1
  end
  local num_leaves = total - num_roots

  local reserve = math.min(DONE_POOL_SIZE, num_leaves)
  local resolved_count = round(num_leaves * RESOLVED_RATIO)
  if resolved_count > num_leaves - reserve then
    resolved_count = math.max(0, num_leaves - reserve)
  end

  local ids: {string} = {}
  for i = 1, total do
    ids[i] = mint_id(i)
  end
  local root_ids: {string} = {}
  for k = 1, num_roots do
    root_ids[k] = ids[k]
  end
  local leaf_ids: {string} = {}
  for i = 1, num_leaves do
    leaf_ids[i] = ids[num_roots + i]
  end

  -- `beats` is recorded on the WINNER only (`_work.gitcompare`): chain the
  -- roots first (root k beats root k+1, so every root but the last has a
  -- placement), then, if the target needs more winners than roots supply,
  -- pair up leaves the same way.
  local winner_target = math.max(1, round(total * BEATS_WINNER_RATIO))
  local beats_of: {string: string} = {}
  local made = 0
  local chain_len = math.min(num_roots - 1, winner_target)
  for k = 1, chain_len do
    beats_of[root_ids[k]] = root_ids[k + 1]
    made = made + 1
  end
  local li = 1
  while made < winner_target and li + 1 <= num_leaves do
    beats_of[leaf_ids[li]] = leaf_ids[li + 1]
    made = made + 1
    li = li + 2
  end

  local resolution_of: {string: string} = {}
  for i = 1, resolved_count do
    if i % 2 == 0 then
      resolution_of[leaf_ids[i]] = "completed"
    else
      resolution_of[leaf_ids[i]] = "not-planned"
    end
  end
  local done_pool: {string} = {}
  for i = num_leaves - reserve + 1, num_leaves do
    done_pool[#done_pool + 1] = leaf_ids[i]
  end

  -- `blocked_by`: a strictly-increasing chain over the OPEN leaves (never
  -- the ones `resolution_of` just closed, or `next` would have nothing to
  -- walk past) — leaf i waits on leaf i-1, which can never cycle, so this
  -- needs none of `cmd_block`'s own deadlock check (bypassed along with
  -- the rest of that verb).
  local blocked_target = round(total * BLOCKED_RATIO)
  local blocker_of: {string: string} = {}
  local open_start = resolved_count + 1
  for i = open_start + 1, math.min(open_start + blocked_target, num_leaves) do
    blocker_of[leaf_ids[i]] = leaf_ids[i - 1]
  end

  local tmp_base = os.getenv("TEST_TMPDIR") or os.getenv("TMPDIR") or "/tmp"
  hermetic_git_env(tmp_base)
  local root_dir = fs.join(tmp_base, ("gitboard-perf-fixture-n%d"):format(total))
  local rok, rerr = fs.remove_all(root_dir)
  if not rok then
    return nil, "remove_all: " .. tostring(rerr)
  end
  assert(fs.make_dirs(root_dir))
  local bare = fs.join(root_dir, "remote.git")
  git(root_dir, {"init", "-q", "--bare", bare})
  git(bare, {"config", "core.createObject", "rename"})
  local clone_dir = fs.join(root_dir, "clone")
  git(root_dir, {"clone", "-q", bare, clone_dir})
  git(clone_dir, {"config", "core.createObject", "rename"})
  local iok, ierr = store.init_repo(clone_dir)
  if not iok then
    return nil, "init_repo: " .. ierr
  end
  local s, serr = store.open(clone_dir)
  if s == nil then
    return nil, serr
  end

  for k = 1, num_roots do
    local id = root_ids[k]
    local it, derr = item.decode({
        id = id, title = ("fixture root %04d"):format(k),
        beats = beats_of[id] or "",
      })
    if it == nil then
      return nil, "decode root " .. id .. ": " .. derr
    end
    local sok, serr2 = storewrite.save(s, it, "seed " .. id:sub(1, 8), FIXTURE_SPEC)
    if not sok then
      return nil, "save root " .. id .. ": " .. serr2
    end
  end
  for i = 1, num_leaves do
    local id = leaf_ids[i]
    local parent = root_ids[((i - 1) % num_roots) + 1]
    local raw: {string: any} = {
      id = id, title = ("fixture leaf %06d"):format(i), parent = parent,
      beats = beats_of[id] or "", resolution = resolution_of[id] or "",
    }
    local blocker = blocker_of[id]
    if blocker ~= nil then
      raw.blocked_by = blocker
      raw.block_reason = {[blocker] = "waiting on a prerequisite"}
    end
    local it, derr = item.decode(raw)
    if it == nil then
      return nil, "decode leaf " .. id .. ": " .. derr
    end
    local sok, serr2 = storewrite.save(s, it, "seed " .. id:sub(1, 8), FIXTURE_SPEC)
    if not sok then
      return nil, "save leaf " .. id .. ": " .. serr2
    end
  end

  local pok, perr = publish.publish(s)
  if not pok then
    return nil, "publish: " .. perr
  end

  return {
    root = root_dir, bare = bare, clone = clone_dir, n = total,
    sample_id = root_ids[1],
    compare_winner = root_ids[1], compare_loser = root_ids[2],
    done_pool = done_pool,
  }
end

local record fixture
  type Fixture = Fixture
  build: function(n?: integer): Fixture, string
  fresh_clone: function(bare: string, dest: string): string, string
end

local M: fixture = {
  build = build,
  fresh_clone = fresh_clone,
}

return M
