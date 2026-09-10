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
--- branches and paths are refused unless explicitly validated with --adopt.
--- Pinned cosmic targets use private verified runtime snapshots; --fetch
--- explicitly authorizes acquisition on a miss and dependency fetching.
--- Each caller-prepared `--ref`
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
local receipt = require("_work.preparation_receipt")
local env = require("cosmic.env")
local fs = require("cosmic.fs")
local gate = require("_work.gitgate")
local item = require("_work.item")
local repository_map = require("_work.repository_map")
local store = require("_work.store")
local adoption = require("_work.worktree_adopt")
local runtime = require("_work.worktree_runtime")
local repoprofile = require("_work.repoprofile")

local active_claim = receipt.active_claim

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

--- Ask Git for effective identity without rewriting shared configuration.
local function identity_refusal(path: string): string
  for _, key in ipairs({"GIT_AUTHOR_IDENT", "GIT_COMMITTER_IDENT"}) do
    local r, err = child.run({"git", "var", key}, {cwd = path})
    if r == nil or not r.ok then
      return ("%s unavailable in %s: %s; configure user.name and user.email "
        .. "with `git -C %q config --local KEY VALUE`, use that checkout's "
        .. "--worktree scope, or provide intentional Git identity environment overrides")
      :format(key, path, r ~= nil and r.stderr or err, path)
    end
  end
  return ""
end

--- Validate repository-independent checkout postconditions, not build artifacts.
local function checkout_refusal(path: string, expected: string): string
  if not fs.is_dir(path) then return "checkout directory is missing: " .. path end
  local head, err = product_commit(path, "HEAD")
  if head == "" then return err end
  if head ~= expected then
    return ("checkout HEAD %s does not equal requested commit %s"):format(head, expected)
  end
  return identity_refusal(path)
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

local run_step = runtime.run_step

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
--- @return string Bootstrap status (not artifact validation), empty on failure
--- @return string Failure diagnostic, empty on success
local function bootstrap(path: string, verbose: boolean): string, string
  if fs.is_file(fs.join(path, "bin/cosmic")) then
    if env.get("GITBOARD_WORKTREE_BOOTSTRAP") == "0" then
      return "cosmic (skipped: GITBOARD_WORKTREE_BOOTSTRAP=0)", ""
    end
    local ok, err = run_step(path, {"bin/cosmic", "--make", "build"}, verbose)
    if not ok then return "", err end
    return "cosmic (local build)", ""
  end
  if fs.is_dir(fs.join(path, "third_party/lua")) then
    return "cosmopolitan (nothing needed)", ""
  end
  return "nothing (unrecognized tree)", ""
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

--- Reconfirm live authority, checkout, pin and private execution bytes at
--- each externally visible preparation boundary. Renewals update only control.
local function checked(c: adoption.Context, pin: runtime.Pin,
    running?: runtime.Runtime): string
  local current, err = adoption.recheck(c)
  if current == nil then return err end
  local now, perr = runtime.inspect(c.path, c.expected)
  if now == nil then return perr ~= "" and perr or "target pin disappeared" end
  if now.text ~= pin.text then return "target pin changed during preparation" end
  if running ~= nil then
    err = runtime.recheck(running)
    if err ~= "" then return err end
  end
  c.initial = current
  return ""
end

local function bootstrap_and_refs(c: adoption.Context, refs: {string},
    verbose: boolean, fetch: boolean, adopting: boolean): string, string
  local path, expected = c.path, c.expected
  local invalid = checkout_refusal(path, expected)
  if invalid ~= "" then return "", invalid end
  local pin: runtime.Pin
  if repoprofile.resolve(path).kind == "cosmic" then
    pin, invalid = runtime.inspect(path, expected)
    if invalid ~= "" then return "", invalid end
  end
  if pin == nil and (fetch or adopting) then return "", "--adopt/--fetch require a tracked pinned cosmic target" end
  local running: runtime.Runtime
  local bootstrapped, berr = "", ""
  if pin ~= nil and env.get("GITBOARD_WORKTREE_BOOTSTRAP") ~= "0" then
    invalid = checked(c, pin)
    if invalid ~= "" then return "", invalid end
    running, berr = runtime.prepare(c.source, path, pin, fetch, verbose)
    if running == nil then return "", berr ~= "" and berr or "runtime preparation failed" end
    bootstrapped = "cosmic (verified runtime, build process passed)"
  else bootstrapped, berr = bootstrap(path, verbose) end
  if berr ~= "" then return "", berr end
  for _, ref in ipairs(refs) do
    local name = ref_basename(ref)
    local sha = prepared_ref(path, ref)
    if sha == "" then
      return "", ("prepared ref %s is missing — caller must fetch it before worktree")
      :format(ref)
    end
    if pin ~= nil and running ~= nil then
      invalid = checked(c, pin, running)
      if invalid ~= "" then return "", invalid end
    end
    local r = child.run({"git", "update-ref", "refs/spike/" .. name,
        sha}, {cwd = path})
    if r == nil or not r.ok then
      return "", ("recording prepared ref %s failed: %s"):format(ref,
        r ~= nil and r.stderr or "could not run git")
    end
  end
  local final = pin ~= nil and running ~= nil and checked(c, pin, running)
  or checkout_refusal(path, expected)
  if final ~= "" then return "", final end
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
    verbose: boolean, fetch: boolean): integer
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
  local identity = identity_refusal(checkout)
  if identity ~= "" then return gate.verdict_line("worktree", false, identity) end
  local added = child.run({"git", "worktree", "add", "-b", branch, path,
      review_sha}, {cwd = checkout})
  if added == nil or not added.ok then
    return gate.verdict_line("worktree", false,
      ("git worktree add failed: %s"):format(
        added ~= nil and added.stderr or "could not run git"))
  end
  local context: adoption.Context = {s = s, id = it.id, session = st.holder, initial = st,
    source = checkout, branch = branch, path = path, expected = review_sha}
  local bootstrapped, referr = bootstrap_and_refs(context, refs, verbose, fetch, false)
  if referr ~= "" then
    return gate.verdict_line("worktree", false,
      ("checkout created at %s; preparation failed: %s"):format(path, referr))
  end
  return gate.verdict_line("worktree", true,
    ("%s review at %s (commit %s, bootstrap: %s)"):format(handle, path,
      review_sha, bootstrapped))
end

--- worktree: create ID's builder checkout in one command. Refuses
--- before any git or network call unless `session` already holds ID's
--- claim. Explicit --adopt skips creation only after validating that exact
--- claim-bound checkout. Builders and reviewers share the preparation tail;
--- --verbose applies uniformly to either.
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
    verbose: boolean, receipt_file?: string, command?: string, cwd?: string,
    adopt?: string, fetch?: boolean): integer
  if adopt ~= nil and (adopt == "" or receipt_file == nil or receipt_file == "" or review) then
    return gate.verdict_line("worktree", false, "--adopt requires nonempty DIR and --receipt-out, builders only")
  end
  if (adopt ~= nil or fetch) and env.get("GITBOARD_WORKTREE_BOOTSTRAP") == "0" then
    return gate.verdict_line("worktree", false, "--adopt/--fetch refuse bootstrap skipping")
  end
  if receipt_file == "" then return gate.verdict_line("worktree", false, "empty --receipt-out") end
  if (command ~= nil or cwd ~= nil) and (receipt_file == nil or command == nil or cwd == nil
    or command == "" or cwd == "") then
    return gate.verdict_line("worktree", false, "invocation flags require --receipt-out and nonempty command/cwd")
  end
  local file, invocation, directory = receipt_file or "", command or "", cwd or ""
  local opt = receipt.options(file, invocation, directory, review)
  if opt ~= "" then return gate.verdict_line("worktree", false, opt) end
  local it, lerr = store.load(s, id)
  if it == nil then return gate.verdict_line("worktree", false, lerr) end
  local handle = id:sub(-8)
  local st, sterr = active_claim(s, it, session)
  if st == nil then return gate.verdict_line("worktree", false, sterr) end
  if file ~= "" then
    st, sterr = receipt.confirmed(s, it, session)
    if st == nil then return gate.verdict_line("worktree", false, sterr) end
  end
  if review then
    return cmd_worktree_review(s, it, st, root_override, refs, verbose, fetch or false)
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
  if adopt == nil then
    if fs.is_dir(path) or fs.is_file(path) then
      return gate.verdict_line("worktree", false,
        ("%s already exists — never reused"):format(path))
    end
    local brefusal = branch_taken_refusal(checkout, branch)
    if brefusal ~= nil then return gate.verdict_line("worktree", false, brefusal) end
    local made, mkerr = fs.make_dirs(fs.dirname(path))
    if not made then return gate.verdict_line("worktree", false, mkerr) end
  end
  local base_sha, berr = product_commit(checkout, st.product_base)
  if base_sha == "" then
    return gate.verdict_line("worktree", false,
      ("%s — caller must fetch the claim base before worktree"):format(berr))
  end
  local context: adoption.Context = {s = s, id = id, session = session, initial = st,
    source = checkout, branch = branch, path = path, expected = base_sha}
  if adopt ~= nil then
    local refusal = adoption.requested(context, adopt)
    if refusal ~= "" then
      return gate.verdict_line("worktree", false,
        ("checkout retained at %s; preparation failed: %s"):format(adopt, refusal))
    end
  else
    local identity = identity_refusal(checkout)
    if identity ~= "" then return gate.verdict_line("worktree", false, identity) end
    local added = child.run({"git", "worktree", "add", "-b", branch, path,
        base_sha}, {cwd = checkout})
    if added == nil or not added.ok then
      return gate.verdict_line("worktree", false,
        ("git worktree add failed: %s"):format(
          added ~= nil and added.stderr or "could not run git"))
    end
  end
  local bootstrapped, referr = bootstrap_and_refs(context, refs, verbose, fetch or false, adopt ~= nil)
  if referr == "" and file ~= "" then
    referr = receipt.write(s, it, context.initial, checkout, branch, path, bootstrapped, file, invocation, directory)
  end
  if referr ~= "" then
    return gate.verdict_line("worktree", false,
      ("checkout %s at %s; preparation failed: %s%s"):format(
        adopt ~= nil and "retained" or "created", path, referr,
        adopt ~= nil and "" or ("; recovery: gitboard worktree %q --adopt %q --receipt-out FILE")
        :format(id, path)))
  end
  return gate.verdict_line("worktree", true,
    ("%s at %s on %s (bootstrap: %s)"):format(handle, path, branch,
      bootstrapped))
end

local record gitworktree
  cmd_worktree: function(s: store.Store, id: string, session: string,
  root_override: string, refs: {string}, review: boolean,
  verbose: boolean, receipt_file?: string, command?: string, cwd?: string,
  adopt?: string, fetch?: boolean): integer
  default_base: function(repo: string, base: string): string
end

local M: gitworktree = {
  cmd_worktree = cmd_worktree,
  default_base = default_base,
}

return M
