--- `worktree`: the orchestrator's one command for a builder's
--- checkout, run right after `take ID` succeeds. Resolves ID's repo
--- to a LOCAL checkout — the checkout `bin/gitboard` itself runs in
--- when ITS origin already is the item's repo, else the first sibling
--- directory beside it whose origin matches (`--root DIR` skips this
--- and names the checkout directly, also how a test uses a bare
--- fixture with no sibling layout to fake; neither answering refuses,
--- naming the URL to clone) — branches and adds a worktree beside it
--- (never reused: an existing branch or path both refuse, checked
--- before any network call), fetches every `--ref` into it, and
--- bootstraps it. The worktree lands at `<checkout>/../wt/<id8>`,
--- `<id8>` the item id's first 8 characters, `take`'s own branch
--- name — the sequence every builder brief used to spend its first
--- 30-40 tool calls doing by hand.
local child = require("cosmic.child")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local gate = require("_work.gitgate")
local store = require("_work.store")

--- `git remote get-url origin`'s `owner/repo` for an arbitrary local
--- checkout, nil with no readable github origin (`_work.gh.slug`'s
--- URL parse, against any directory — a product repo means asking a
--- checkout the store never opens).
--- @param dir string A local checkout
--- @return string | nil The `owner/name` slug
local function checkout_slug(dir: string): string | nil
  local r, _err = child.run({"git", "remote", "get-url", "origin"}, {cwd = dir})
  if r == nil or not r.ok then return nil end
  local url = (r.stdout or ""):gsub("%s+$", "")
  local owner, name = url:match("github%.com[:/]([^/]+)/(.+)$")
  if owner == nil then return nil end
  return ("%s/%s"):format(owner, (name:gsub("%.git$", "")))
end

--- The checkout `bin/gitboard` itself runs in: `GITBOARD_DIR`'s
--- parent's parent when that guess carries `bin/gitboard`, else the
--- nearest ancestor of this process's cwd that does. Mirrors
--- `_work.brief`'s private `product_root` (duplicated, not exported —
--- the sibling search below asks it a different question).
--- @return string The checkout's absolute path, "" if unknown
local function invoking_checkout(): string
  local dir = env.get("GITBOARD_DIR")
  if dir ~= nil and dir ~= "" then
    local guess = fs.absolute_path(fs.dirname(fs.dirname(dir)))
    if fs.is_file(fs.join(guess, "bin/gitboard")) then return guess end
  end
  local cur, _err = fs.cwd()
  while cur ~= nil do
    if fs.is_file(fs.join(cur, "bin/gitboard")) then return cur end
    local parent = fs.dirname(cur)
    if parent == cur then break end
    cur = parent
  end
  return ""
end

--- The local checkout backing `repo` (`owner/name`): the invoking
--- checkout itself when its OWN origin already is `repo`, else the
--- first sibling directory beside it whose origin matches.
--- @param repo string The item's `owner/name`
--- @return string The checkout's absolute path, "" on failure
--- @return string The refusal, "" on success
local function resolve_checkout(repo: string): string, string
  local here = invoking_checkout()
  if here == "" then
    return "", ("no local checkout of bin/gitboard found to resolve %s "
      .. "against — clone it: https://github.com/%s"):format(repo, repo)
  end
  if checkout_slug(here) == repo then return here, "" end
  local parent = fs.dirname(here)
  local dir, direrr = fs.open_dir(parent)
  if dir == nil then return "", direrr end
  while true do
    local name = dir:read()
    if name == nil then break end
    if name ~= "." and name ~= ".." then
      local cand = fs.join(parent, name)
      if cand ~= here and fs.is_dir(cand) and checkout_slug(cand) == repo then
        dir:close()
        return cand, ""
      end
    end
  end
  dir:close()
  return "", ("no local checkout of %s beside %s — clone it: https://github.com/%s")
  :format(repo, parent, repo)
end

--- ID's PR base: the item's own `base` when set, else `master` for a
--- `cosmopolitan` repo, `main` otherwise — `_work.brief`'s own
--- `<BASE_BRANCH>` rule.
--- @param repo string The item's `owner/name`
--- @param base string The item's own `base` field, "" if unset
--- @return string The branch to fetch and branch off of
local function default_base(repo: string, base: string): string
  if (base or "") ~= "" then return base end
  if repo:find("cosmopolitan", 1, true) ~= nil then return "master" end
  return "main"
end

--- Bootstraps a fresh worktree: `bin/cosmic --make fetch` then
--- `--make build` for a cosmic tree (their own verdict lines are this
--- verb's output — streamed, not captured), nothing for a
--- cosmopolitan tree (its own gate is the builder's first) or a repo
--- this tool does not recognize. `GITBOARD_WORKTREE_BOOTSTRAP=0`
--- skips actually running the cosmic commands — a test's fixture may
--- carry a fake `bin/cosmic` it must never execute — while still
--- detecting and reporting which kind this is.
--- @param path string The fresh worktree
--- @return string What was bootstrapped, for the verdict line
local function bootstrap(path: string): string
  if fs.is_file(fs.join(path, "bin/cosmic")) then
    if env.get("GITBOARD_WORKTREE_BOOTSTRAP") ~= "0" then
      local _r1, _e1 = child.run({"bin/cosmic", "--make", "fetch"},
        {cwd = path, stdout = "inherit", stderr = "inherit"})
      local _r2, _e2 = child.run({"bin/cosmic", "--make", "build"},
        {cwd = path, stdout = "inherit", stderr = "inherit"})
    end
    return "cosmic (fetch + build)"
  end
  if fs.is_dir(fs.join(path, "third_party/lua")) then
    return "cosmopolitan (nothing needed)"
  end
  return "nothing (unrecognized tree)"
end

--- worktree: create ID's builder checkout in one command.
--- @param s store.Store The store
--- @param id string The item to make a checkout for
--- @param root_override string `--root`, "" to auto-resolve
--- @param refs {string} `--ref` occurrences, fetched into the worktree
--- @return integer Exit code
local function cmd_worktree(s: store.Store, id: string, root_override: string,
    refs: {string}): integer
  local it, lerr = store.load(s, id)
  if it == nil then return gate.verdict_line("worktree", false, lerr) end
  local repo = it.repo or ""
  if repo == "" then
    return gate.verdict_line("worktree", false,
      ("%s has no repo set — worktree needs one to resolve a checkout")
      :format(id:sub(1, 8)))
  end
  local checkout = root_override or ""
  if checkout == "" then
    local found, ferr = resolve_checkout(repo)
    if found == "" then return gate.verdict_line("worktree", false, ferr) end
    checkout = found
  end
  local id8 = id:sub(1, 8)
  local base = default_base(repo, it.base or "")
  local path = fs.join(fs.dirname(checkout), "wt", id8)
  if fs.is_dir(path) or fs.is_file(path) then
    return gate.verdict_line("worktree", false,
      ("%s already exists — never reused"):format(path))
  end
  local has_branch = child.run({"git", "rev-parse", "--verify", "--quiet",
      "refs/heads/" .. id8}, {cwd = checkout})
  if has_branch ~= nil and has_branch.ok then
    return gate.verdict_line("worktree", false,
      ("branch %s already exists in %s — never reused"):format(id8, checkout))
  end
  local fetched = child.run({"git", "fetch", "origin", base}, {cwd = checkout})
  if fetched == nil or not fetched.ok then
    return gate.verdict_line("worktree", false,
      ("git fetch origin %s failed: %s"):format(base,
        fetched ~= nil and fetched.stderr or "could not run git"))
  end
  local added = child.run({"git", "worktree", "add", "-b", id8, path,
      "origin/" .. base}, {cwd = checkout})
  if added == nil or not added.ok then
    return gate.verdict_line("worktree", false,
      ("git worktree add failed: %s"):format(
        added ~= nil and added.stderr or "could not run git"))
  end
  for _, ref in ipairs(refs) do
    local r = child.run({"git", "fetch", "origin", ref}, {cwd = path})
    if r == nil or not r.ok then
      return gate.verdict_line("worktree", false,
        ("git fetch origin %s (--ref) failed: %s"):format(ref,
          r ~= nil and r.stderr or "could not run git"))
    end
  end
  return gate.verdict_line("worktree", true,
    ("%s at %s (bootstrapped %s)"):format(id8, path, bootstrap(path)))
end

local record gitworktree
  cmd_worktree: function(s: store.Store, id: string, root_override: string,
  refs: {string}): integer
end

local M: gitworktree = {
  cmd_worktree = cmd_worktree,
}

return M
