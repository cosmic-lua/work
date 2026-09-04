#!/usr/bin/env cosmic
-- The importer: a small fixture repo in the OLD `items/<id>.tl` +
-- `items/<id>.md` layout, with several commits per item and two
-- items, imported into a fresh ref-layout store — asserting replay
-- order, original author dates, sessions parsed from commit subjects,
-- and the repo-default rule the move itself needs.

local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local import = require("_work.import")
local ksuid = require("_work.ksuid")
local literal = require("cosmic.literal")
local product = require("_work.product")
local publish = require("_work.publish")
local store = require("_work.store")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"

local hermetic_config < const > = fs.join(tmpdir, "gitconfig-empty")
assert(fs.write(hermetic_config, ""))
assert(env.set("GIT_CONFIG_GLOBAL", hermetic_config))
assert(env.set("GIT_CONFIG_NOSYSTEM", "1"))

--- Commit `items/<id>.tl` (from `fields`) and, when given, `.md` in
--- the FROM repo, at the given author/committer date, as one commit.
--- @param root string The old-layout repo
--- @param id string Item id
--- @param fields {string: any} The item's literal fields (no "id" key needed)
--- @param spec string | nil The spec sidecar; nil leaves it untouched
--- @param subject string Commit subject
--- @param at_s integer Author/committer date, epoch seconds
--- @return string The commit sha
local function commit_old_layout(root: string, id: string, fields: {string: any},
    spec: string | nil, subject: string, at_s: integer): string
  fields = fields or {}
  fields.id = id
  assert(fs.make_dirs(fs.join(root, "items")))
  assert(literal.format_file(fs.join(root, "items", id .. ".tl"), fields))
  if spec ~= nil then
    assert(fs.write(fs.join(root, "items", id .. ".md"), spec))
  end
  local when = ("%d +0000"):format(at_s)
  local full: {string} = {"git", "add", "-A"}
  local r = check.must(child.run(full, {cwd = root}))
  assert(r.ok, "git add failed: " .. r.stderr)
  local commit = check.must(child.run({"git", "commit", "-q", "-m", subject},
      {cwd = root, env = env.list({set = {
              GIT_AUTHOR_DATE = when, GIT_COMMITTER_DATE = when,
              GIT_AUTHOR_NAME = "Claude", GIT_AUTHOR_EMAIL = "noreply@anthropic.com",
              GIT_COMMITTER_NAME = "Claude", GIT_COMMITTER_EMAIL = "noreply@anthropic.com",
            }})}))
  assert(commit.ok, "git commit failed: " .. commit.stderr)
  local sha = check.must(child.run({"git", "rev-parse", "HEAD"}, {cwd = root}))
  return (sha.stdout:gsub("%s+$", ""))
end

local counter = 0
--- A fresh deterministic, well-formed id.
local function fresh_id(): string
  counter = counter + 1
  return check.must(ksuid.encode(1700000000 + counter, ("\0"):rep(16)))
end

-- Full replay: two items, several commits each, one whose `repo` was
-- never set (gets the product default) and one whose `base` was
-- "board" (gets the board repo and `base = "main"`) — the exact
-- repo-default rule the move needs — plus original dates and the
-- session a "by <session>" subject names.
local function test_import_replays_history_dates_authors_and_defaults()
  local from = fs.join(tmpdir, "import-from")
  assert(fs.remove_all(from))
  assert(fs.make_dirs(from))
  assert(child.run({"git", "init", "-q", from}))

  local parent = fresh_id()
  commit_old_layout(from, parent, {title = "an outcome"}, nil,
    "new " .. parent:sub(1, 8) .. " an outcome", 1700000000)

  local a = fresh_id()
  commit_old_layout(from, a, {title = "slice A", parent = parent},
    "## Change\nDo A.\n", "new " .. a:sub(1, 8) .. " slice A", 1700000100)
  commit_old_layout(from, a,
    {title = "slice A", parent = parent, claim = "session-x"}, nil,
    "take " .. a:sub(1, 8) .. " by session-x", 1700000200)
  commit_old_layout(from, a,
    {title = "slice A", parent = parent, resolution = "completed"}, nil,
    "done " .. a:sub(1, 8) .. " completed (todo)", 1700000300)

  local b = fresh_id()
  commit_old_layout(from, b,
    {title = "slice B", parent = parent, base = "board"}, nil,
    "new " .. b:sub(1, 8) .. " slice B", 1700000150)
  commit_old_layout(from, b,
    {title = "slice B (refined)", parent = parent, base = "board"}, nil,
    "set " .. b:sub(1, 8) .. " title", 1700000250)

  local rev = check.must(child.run({"git", "rev-parse", "HEAD"}, {cwd = from}))
  local rev_s = (rev.stdout:gsub("%s+$", ""))

  local target = fs.join(tmpdir, "import-to")
  assert(fs.remove_all(target))
  assert(store.init_repo(target))
  local s = check.must(store.open(target))
  local n, ierr = import.run(s, from, rev_s)
  assert(n ~= nil, tostring(ierr))
  assert(n == 3, ("3 items imported (parent, a, b): got %d"):format(n))

  -- a: ended (resolution set on its last commit), repo defaulted.
  local ia = check.must(store.load(s, a))
  assert(ia.resolution == "completed", "a's final state carried over")
  assert(ia.repo == product.REPO, "the product-repo default applied: "
    .. ia.repo)
  assert(ia.claim == "", "a done item's claim was cleared, and stays so")
  assert(#ia.builders == 0, "and it was never taken, so no builders on record")
  local ea = check.must(publish.history(s, a))
  assert(#ea == 3, "a's whole history replayed: " .. #ea)
  -- history() is newest first; the replayed order matches the
  -- original commit order (new, then take, then done).
  assert(ea[3].subject:find("^new", 1) ~= nil, "oldest first when reversed: "
    .. ea[3].subject)
  assert(ea[2].subject:find("^take", 1) ~= nil, "then the take: " .. ea[2].subject)
  assert(ea[1].subject:find("^done", 1) ~= nil, "newest last->first: "
    .. ea[1].subject)
  -- The ORIGINAL author dates rode through, not "now": every replayed
  -- commit lands in 2023, the year the fixture's epoch seconds fall
  -- in — a fresh import run always dates in whatever year it runs,
  -- so this could only pass if the original date survived.
  for _, ev in ipairs(ea) do
    assert(ev.at:match("^2023%-11%-14T") ~= nil,
      "the original author date rode through, not the import's own: " .. ev.at)
  end

  -- The session `take ... by session-x` named is the author of THAT
  -- commit, not the tool identity — read straight from git.
  local r = check.must(child.run({"git", "log", "--format=%an|%ae", s.leased_ref[a]},
      {cwd = target}))
  assert(r.ok, "git log failed: " .. r.stderr)
  local lines: {string} = {}
  for line in r.stdout:gmatch("([^\n]+)") do
    lines[#lines + 1] = line
  end
  assert(#lines == 3, "3 commits on a's ref: " .. #lines)
  -- Newest first: done (no "by <session>" in its subject, tool
  -- identity), take (named session-x), new (no session, tool identity).
  assert(lines[1] == "Claude|noreply@anthropic.com",
    "the done commit named no session, so the tool identity: " .. lines[1])
  assert(lines[2] == "session-x|session-x@board",
    "the take commit's author is the named session: " .. lines[2])
  assert(lines[3] == "Claude|noreply@anthropic.com",
    "the filing commit named no session, so the tool identity: " .. lines[3])

  -- b: the board's own repo-default rule (base == "board").
  local ib = check.must(store.load(s, b))
  assert(ib.repo == product.BOARD_REPO, "the board-repo default applied: "
    .. ib.repo)
  assert(ib.base == "main", "and base becomes main: " .. ib.base)
  assert(ib.title == "slice B (refined)", "b's later revision won: " .. ib.title)
  local eb = check.must(publish.history(s, b))
  assert(#eb == 2, "b's whole history replayed: " .. #eb)

  -- The root is a root: no repo-default rule touches it.
  local ip = check.must(store.load(s, parent))
  assert(ip.repo == "", "a root's repo is never defaulted: " .. ip.repo)
end

-- Importing is idempotent to inspect afterward: a second `store.list`
-- reads the same board `import.run` just wrote, through the ordinary
-- store API — the importer leaves nothing special behind.
local function test_imported_items_read_through_the_ordinary_store_api()
  local from = fs.join(tmpdir, "import-from-plain")
  assert(fs.remove_all(from))
  assert(fs.make_dirs(from))
  assert(child.run({"git", "init", "-q", from}))
  local id = fresh_id()
  commit_old_layout(from, id, {title = "a plain item", repo = "cosmic-lua/cosmic"},
    "## Change\nDo it.\n", "new " .. id:sub(1, 8) .. " a plain item", 1700000000)
  local rev = check.must(child.run({"git", "rev-parse", "HEAD"}, {cwd = from}))
  local rev_s = (rev.stdout:gsub("%s+$", ""))

  local target = fs.join(tmpdir, "import-to-plain")
  assert(fs.remove_all(target))
  assert(store.init_repo(target))
  local s = check.must(store.open(target))
  local n = check.must(import.run(s, from, rev_s))
  assert(n == 1)
  local all = check.must(store.list(s))
  assert(#all == 1 and all[1].id == id, "the item lists normally")
  assert(store.read_spec(s, id) == "## Change\nDo it.\n", "and its spec reads")
end
