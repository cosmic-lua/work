--- `worktree` prepares a local checkout for a confirmed, active claim.
--- The item repository resolves only through the checkout-local
--- `gitboard.repository` map or the explicit `--root` override. Builder work
--- starts at the exact product commit stored in `claim_base`; review work
--- starts at the exact `handover_head`. Gitboard never fetches either one.
---
--- The stable branch is `work/<handle>/<claim-root-short>`, where the handle
--- is the item's last eight characters. Its worktree lives at the matching
--- nested path under `<checkout>/../wt`. A renewal preserves that name; a
--- post-expiry acquisition gets a new claim root and cannot collide. Existing
--- branches and paths are refused, never reused. Each caller-prepared `--ref`
--- is copied into `refs/spike/<ref-basename>`. The bootstrap's local-only
--- `--make build` is quiet by default: the step reduces to its own
--- `PASS`/`FAIL` summary line, `--verbose` streams the hundreds of
--- per-file `compile`/`compile-batch` lines verbatim instead — a
--- failed step always prints everything captured, unfiltered,
--- whichever mode is in play.
---
--- `--review` uses the same whole-item lease and branch identity but checks
--- out the handed-over commit. `--verbose` applies identically.
local child = require("cosmic.child")
local claim = require("_work.claim")
local claimbatch = require("_work.claimbatch")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local gate = require("_work.gitgate")
local item = require("_work.item")
local repository_map = require("_work.repository_map")
local store = require("_work.store")

--- Recover and validate the Git-backed lease which authorizes local work.
--- Looking at the durable holder field alone is insufficient: ordinary item
--- mutations may sit above the control commit, and a two-hour lease can have
--- expired without rewriting the item. The returned root is the stable branch
--- identity; renewals change only the control/deadline.
local function active_claim(s: store.Store, it: item.Item, session: string):
  claim.State | nil, string
  local holder = it.claim or ""
  if holder == "" then
    return nil, ("REFUSED: %s is not claimed by %s — claim it first")
    :format(it.id:sub(-8), session)
  end
  local pointer = it.claim_batch or ""
  if pointer == "" then return nil, "item has no claim batch" end
  local st, err = claimbatch.read_state(s.root, pointer, it.id)
  if err ~= "" then return nil, err end
  local status = claim.status(st, os.time())
  if status ~= "active" then
    if status == "future" then
      return nil, "REFUSED: claim timestamp is more than five minutes in the future"
    end
    return nil, ("REFUSED: %s's claim has expired — claim it again")
    :format(it.id:sub(-8))
  end
  if st == nil then return nil, "active claim has no state" end
  if st.holder ~= session then
    return nil, ("REFUSED: %s is claimed by %s, not %s")
    :format(it.id:sub(-8), st.holder, session)
  end
  return st, ""
end

--- Resolve a full or abbreviated product commit without consulting a branch,
--- remote, or provider. The claim and handover paths pass full ids.
local function product_commit(root: string, sha: string): string, string
  if sha == "" then return "", "no product commit was recorded" end
  local r, err = child.run({"git", "rev-parse", "--verify", sha .. "^{commit}"},
    {cwd = root})
  if r == nil then return "", err end
  if not r.ok then return "", ("product commit %s is not present locally"):format(sha) end
  return (r.stdout:gsub("%s+$", "")), ""
end

--- Compatibility helper for callers that need a repository's conventional
--- base name. Claim worktree creation itself never guesses a branch: it uses
--- the exact product commit recorded in the claim.
--- @param repo string The item's `owner/name`
--- @param base string The item's own `base` field, "" if unset
--- @return string The branch to fetch and branch off of
local function default_base(repo: string, base: string): string
  if (base or "") ~= "" then return base end
  if repo:find("cosmopolitan", 1, true) ~= nil then return "master" end
  return "main"
end

--- The refusal a fresh worktree earns when `branch` already exists in
--- `checkout` — never reused, builder or review.
--- @param checkout string The local checkout to check
--- @param branch string The branch name at stake
--- @return string | nil The refusal
local function branch_taken_refusal(checkout: string, branch: string): string | nil
  local has_branch = child.run({"git", "rev-parse", "--verify", "--quiet",
      "refs/heads/" .. branch}, {cwd = checkout})
  if has_branch ~= nil and has_branch.ok then
    return ("branch %s already exists in %s — never reused"):format(branch, checkout)
  end
  return nil
end

--- The summary line(s) `--make` itself prints inside a step's captured
--- output: `verb: PASS (...)`/`verb: FAIL (...)`, the exact shape
--- `_tool.records.format_verdict` writes (`fetch: PASS (N pins)`,
--- `build: PASS (N files, 1 binary)`) — everything else, a `compile`/
--- `compile-batch` line per source file or `unpack`/`fetch`/`patch`
--- per pin, is dropped.
--- @param text string A step's captured stdout
--- @return {string} The summary lines, in the order they appeared
local function summary_of(text: string): {string}
  local out: {string} = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^%a+: PASS") ~= nil or line:match("^%a+: FAIL") ~= nil then
      out[#out + 1] = line
    end
  end
  return out
end

--- Runs one local bootstrap step (a `bin/cosmic --make build`
--- invocation). `verbose` streams it verbatim — `stdout`/`stderr`
--- inherited, as every step ran before this flag existed. Quiet (the
--- default) instead captures it and prints only `summary_of` its
--- output on success, or everything captured, unfiltered, the moment
--- it fails — a failed bootstrap is never harder to read than a green
--- one used to be.
--- @param path string The worktree to run it in
--- @param argv {string} The full `bin/cosmic ...` argv
--- @param verbose boolean Stream the step verbatim instead of summarizing
local function run_step(path: string, argv: {string}, verbose: boolean)
  if verbose then
    local _r, _e = child.run(argv, {cwd = path, stdout = "inherit", stderr = "inherit"})
    return
  end
  local r, _e = child.run(argv, {cwd = path})
  if r == nil then return end
  if not r.ok then
    print(r.stdout .. r.stderr)
    return
  end
  for _, line in ipairs(summary_of(r.stdout)) do
    print(line)
  end
end

--- Bootstraps a fresh worktree, builder or review: `bin/cosmic --make
--- build` for a cosmic tree (`run_step` decides
--- how much of their own output reaches the caller), nothing for a
--- cosmopolitan tree (its own gate is the builder's first) or a repo
--- this tool does not recognize. `GITBOARD_WORKTREE_BOOTSTRAP=0` skips
--- actually running the cosmic commands — a test's fixture may carry
--- a fake `bin/cosmic` it must never execute — while still detecting
--- and reporting which kind this is.
--- @param path string The fresh worktree
--- @param verbose boolean Stream fetch/build verbatim instead of
--- summarizing them (`--verbose`)
--- @return string What was bootstrapped, for the verdict line
local function bootstrap(path: string, verbose: boolean): string
  if fs.is_file(fs.join(path, "bin/cosmic")) then
    if env.get("GITBOARD_WORKTREE_BOOTSTRAP") ~= "0" then
      run_step(path, {"bin/cosmic", "--make", "build"}, verbose)
    end
    return "cosmic (local build)"
  end
  if fs.is_dir(fs.join(path, "third_party/lua")) then
    return "cosmopolitan (nothing needed)"
  end
  return "nothing (unrecognized tree)"
end

--- The local name a `--ref` value lands under: its last `/`-separated
--- segment, itself when it has none — so `feature/x` and a bare `x`
--- both land at `refs/spike/x`.
--- @param ref string The `--ref` value as given
--- @return string The basename to store it under
local function ref_basename(ref: string): string
  return ref:match("([^/]+)$") or ref
end

--- Resolve one caller-prepared ref without contacting a remote. A
--- fully-qualified ref is used verbatim; a short name may name a local
--- branch or an already-fetched remote-tracking branch. Ambiguous names
--- follow that explicit order rather than Git's DWIM rules.
--- @param path string The product checkout
--- @param name string The caller's ref spelling
--- @return string Commit OID, or "" when the ref is not present
local function prepared_ref(path: string, name: string): string
  local candidates: {string}
  if name:match("^refs/") ~= nil then
    candidates = {name}
  else
    candidates = {"refs/heads/" .. name}
  end
  for _, ref in ipairs(candidates) do
    local r = child.run({"git", "rev-parse", "--verify", "--quiet",
        ref .. "^{commit}"}, {cwd = path})
    if r ~= nil and r.ok then
      local sha = (r.stdout or ""):gsub("%s+$", "")
      return sha
    end
  end
  return ""
end

--- Bootstraps `path` then copies each already-present `--ref` into
--- `refs/spike/<basename>`. The caller owns every fetch; a missing ref
--- is an actionable precondition failure, never a reason for gitboard
--- to contact a remote itself.
--- @param path string The fresh worktree
--- @param refs {string} Caller-prepared `--ref` occurrences
--- @param verbose boolean Stream the bootstrap verbatim (`--verbose`)
--- @return string The bootstrap label, "" on a ref-fetch failure
--- @return string The failure, "" on success
local function bootstrap_and_refs(path: string, refs: {string},
    verbose: boolean): string, string
  local bootstrapped = bootstrap(path, verbose)
  for _, ref in ipairs(refs) do
    local name = ref_basename(ref)
    local sha = prepared_ref(path, ref)
    if sha == "" then
      return "", ("prepared ref %s is missing — caller must fetch it before worktree")
      :format(ref)
    end
    local r = child.run({"git", "update-ref", "refs/spike/" .. name,
        sha}, {cwd = path})
    if r == nil or not r.ok then
      return "", ("recording prepared ref %s failed: %s"):format(ref,
        r ~= nil and r.stderr or "could not run git")
    end
  end
  return bootstrapped, ""
end

--- worktree --review: create ID's review checkout at the exact handed-over
--- commit. Refuses before any product Git operation unless `session` holds
--- the item's active whole-item claim.
--- @param it item.Item The item to make a review checkout for (loaded)
--- @param root_override string `--root`, "" to auto-resolve
--- @param refs {string} Caller-prepared `--ref` occurrences copied into the worktree
--- as `refs/spike/<ref-basename>` after bootstrap
--- @param verbose boolean `--verbose`: stream the bootstrap's fetch/build
--- output verbatim instead of just its summary line(s)
--- @return integer Exit code
local function cmd_worktree_review(s: store.Store, it: item.Item,
    st: claim.State, root_override: string, refs: {string},
    verbose: boolean): integer
  local handle = it.id:sub(-8)
  local repo = it.repo or ""
  if repo == "" then
    return gate.verdict_line("worktree", false,
      ("%s has no repo set — worktree needs one to resolve a checkout")
      :format(handle))
  end
  local checkout, maperr = repository_map.resolve(s.root, repo, root_override or "")
  if checkout == nil then return gate.verdict_line("worktree", false, maperr) end
  local branch = claim.branch(it.id, st.root)
  local path = fs.join(fs.dirname(checkout), "wt", branch)
  if fs.is_dir(path) or fs.is_file(path) then
    return gate.verdict_line("worktree", false,
      ("%s already exists — never reused"):format(path))
  end
  local brefusal = branch_taken_refusal(checkout, branch)
  if brefusal ~= nil then return gate.verdict_line("worktree", false, brefusal) end
  local made, mkerr = fs.make_dirs(fs.dirname(path))
  if not made then return gate.verdict_line("worktree", false, mkerr) end
  local review_sha, herr = product_commit(checkout, it.handover_head or "")
  if review_sha == "" then
    return gate.verdict_line("worktree", false,
      ("%s — caller must fetch the handed-over commit before worktree")
      :format(herr))
  end
  local added = child.run({"git", "worktree", "add", "-b", branch, path,
      review_sha}, {cwd = checkout})
  if added == nil or not added.ok then
    return gate.verdict_line("worktree", false,
      ("git worktree add failed: %s"):format(
        added ~= nil and added.stderr or "could not run git"))
  end
  local bootstrapped, referr = bootstrap_and_refs(path, refs, verbose)
  if referr ~= "" then return gate.verdict_line("worktree", false, referr) end
  return gate.verdict_line("worktree", true,
    ("%s review at %s (commit %s, bootstrapped %s)"):format(handle, path,
      review_sha, bootstrapped))
end

--- worktree: create ID's builder checkout in one command. Refuses
--- before any git or network call unless `session` already holds ID's
--- claim. `--review` (`worktree_review`) is the review-checkout twin
--- of this, dispatched separately since the two share almost no
--- refusal or shape once past resolving the repo; `--verbose` applies
--- uniformly to either.
--- @param s store.Store The store
--- @param id string The item to make a checkout for
--- @param session string The caller's session; must hold ID's claim
--- @param root_override string `--root`, "" to auto-resolve
--- @param refs {string} Caller-prepared `--ref` occurrences copied into the worktree
--- as `refs/spike/<ref-basename>` after bootstrap
--- @param review boolean `--review`: provision the review checkout instead
--- @param verbose boolean `--verbose`: stream the bootstrap's fetch/build
--- output verbatim instead of just its summary line(s)
--- @return integer Exit code
local function cmd_worktree(s: store.Store, id: string, session: string,
    root_override: string, refs: {string}, review: boolean,
    verbose: boolean): integer
  local it, lerr = store.load(s, id)
  if it == nil then return gate.verdict_line("worktree", false, lerr) end
  local handle = id:sub(-8)
  local st, sterr = active_claim(s, it, session)
  if st == nil then return gate.verdict_line("worktree", false, sterr) end
  if review then
    return cmd_worktree_review(s, it, st, root_override, refs, verbose)
  end
  local repo = it.repo or ""
  if repo == "" then
    return gate.verdict_line("worktree", false,
      ("%s has no repo set — worktree needs one to resolve a checkout")
      :format(handle))
  end
  local checkout, maperr = repository_map.resolve(s.root, repo, root_override or "")
  if checkout == nil then return gate.verdict_line("worktree", false, maperr) end
  local branch = claim.branch(id, st.root)
  local path = fs.join(fs.dirname(checkout), "wt", branch)
  if fs.is_dir(path) or fs.is_file(path) then
    return gate.verdict_line("worktree", false,
      ("%s already exists — never reused"):format(path))
  end
  local brefusal = branch_taken_refusal(checkout, branch)
  if brefusal ~= nil then return gate.verdict_line("worktree", false, brefusal) end
  local made, mkerr = fs.make_dirs(fs.dirname(path))
  if not made then return gate.verdict_line("worktree", false, mkerr) end
  local base_sha, berr = product_commit(checkout, st.product_base)
  if base_sha == "" then
    return gate.verdict_line("worktree", false,
      ("%s — caller must fetch the claim base before worktree"):format(berr))
  end
  local added = child.run({"git", "worktree", "add", "-b", branch, path,
      base_sha}, {cwd = checkout})
  if added == nil or not added.ok then
    return gate.verdict_line("worktree", false,
      ("git worktree add failed: %s"):format(
        added ~= nil and added.stderr or "could not run git"))
  end
  local bootstrapped, referr = bootstrap_and_refs(path, refs, verbose)
  if referr ~= "" then return gate.verdict_line("worktree", false, referr) end
  return gate.verdict_line("worktree", true,
    ("%s at %s on %s (bootstrapped %s)"):format(handle, path, branch,
      bootstrapped))
end

local record gitworktree
  cmd_worktree: function(s: store.Store, id: string, session: string,
  root_override: string, refs: {string}, review: boolean,
  verbose: boolean): integer
  default_base: function(repo: string, base: string): string
end

local M: gitworktree = {
  cmd_worktree = cmd_worktree,
  default_base = default_base,
}

return M
