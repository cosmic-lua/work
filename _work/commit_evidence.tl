--- Commit-only evidence for handover, verdict and completion.
---
--- This module performs local Git reads only. It never names a provider,
--- opens a network connection, reads credentials, or treats a pull request
--- as evidence. The caller is responsible for fetching the commits it wants
--- gitboard to inspect before invoking these checks.
local child = require("cosmic.child")

--- Run a Git command against the caller-managed product repository.
--- @param root string The local product repository
--- @param args {string} Arguments after `git`
--- @return child.Result | nil The completed process
--- @return string Error message
local function git(root: string, args: {string}): child.Result | nil, string
  local argv: {string} = {"git"}
  for _, value in ipairs(args) do argv[#argv + 1] = value end
  return child.run(argv, {cwd = root})
end

--- Resolve one evidence value to its full object id, accepting only a
--- hexadecimal commit id as input. A branch, tag, revision expression, or
--- non-commit object is refused even when Git could otherwise resolve it.
--- @param root string The local product repository
--- @param given string The commit id supplied by the caller
--- @return string | nil The canonical full commit id
--- @return string Error message
local function commit_id(root: string, given: string): string | nil, string
  if not given:match("^[0-9a-fA-F]+$") or #given < 7 or #given > 64 then
    return nil, ("not a commit id: %s"):format(given)
  end
  local r, err = git(root, {"rev-parse", "--verify", given .. "^{commit}"})
  if r == nil then return nil, err end
  if not r.ok then
    return nil, ("commit %s is not present in %s"):format(given, root)
  end
  local full = (r.stdout:gsub("%s+$", "")):lower()
  if not full:match("^[0-9a-f]+$") then
    return nil, ("git returned an invalid commit id for %s"):format(given)
  end
  return full, ""
end

--- Whether `ancestor` is in `descendant`'s history. Both ids must already be
--- canonical ids returned by `commit_id`.
--- @param root string The local product repository
--- @param ancestor string The possible ancestor
--- @param descendant string The possible descendant
--- @return boolean True when the ancestry is present
--- @return string Error message
local function is_ancestor(root: string, ancestor: string,
    descendant: string): boolean, string
  local r, err = git(root, {"merge-base", "--is-ancestor", ancestor, descendant})
  if r == nil then return false, err end
  if r.ok then return true, "" end
  if r.code == 1 then return false, "" end
  return false, ("git merge-base failed: %s"):format(r.stderr)
end

--- Verify the commit recorded at handover can have been built from the base
--- captured by the claim. Returns canonical ids so callers always record
--- full object names, even when the command line used unambiguous prefixes.
--- @param root string The local product repository
--- @param claim_base string Base commit captured by the claim
--- @param head string Handover/verdict commit
local record Lineage
  head: string
  base: string
end

--- @return Lineage | nil Canonical head and base
--- @return string Error message
local function verify_lineage(root: string, claim_base: string,
    head: string): Lineage | nil, string
  local base, berr = commit_id(root, claim_base)
  if base == nil then return nil, berr end
  local tip, terr = commit_id(root, head)
  if tip == nil then return nil, terr end
  local descends, derr = is_ancestor(root, base, tip)
  if derr ~= "" then return nil, derr end
  if not descends then
    return nil, ("commit %s does not descend from claim base %s")
    :format(tip, base)
  end
  return {head = tip, base = base}, ""
end

--- Canonical exact patch for the content change `from..to`. Only Git's
--- base-dependent headers are normalized: blob ids and hunk line offsets.
--- Paths, modes, context, added/removed bytes (including whitespace), and
--- binary patch payloads remain byte-for-byte significant.
--- @param root string The local product repository
--- @param from string The before commit
--- @param to string The after commit
--- @return string | nil Canonical exact patch
--- @return string Error message
local function exact_patch(root: string, from: string,
    to: string): string | nil, string
  local diff, derr = git(root, {"diff", "--binary", "--full-index",
      "--no-color", "--no-ext-diff", "--no-renames", from, to, "--"})
  if diff == nil then return nil, derr end
  if not diff.ok then
    return nil, ("git diff failed: %s"):format(diff.stderr)
  end
  if diff.stdout == "" then
    return nil, ("%s..%s has no content patch"):format(from, to)
  end
  local lines: {string} = {}
  for line in (diff.stdout .. "\n"):gmatch("([^\n]*)\n") do
    -- Blob names depend on the old and newly based trees, not on the bytes
    -- described by the patch body. Preserve an optional mode suffix.
    local mode = line:match("^index [0-9a-f]+%.%.[0-9a-f]+ (.+)$")
    if mode ~= nil then
      line = "index <old>..<new> " .. mode
    elseif line:match("^index [0-9a-f]+%.%.[0-9a-f]+$") then
      line = "index <old>..<new>"
    elseif line:match("^@@ ") then
      -- Line offsets move when a rebase adds unrelated lines above a hunk.
      -- The optional function/context heading and every following content
      -- line remain exact.
      local context = line:match("^@@ [^@]+ @@(.*)$") or ""
      line = "@@ @@" .. context
    end
    lines[#lines + 1] = line
  end
  return table.concat(lines, "\n"), ""
end

--- Verify that a locally present landed commit represents the accepted
--- commit. History-preserving merges pass by ancestry. Squash or rebased
--- landing falls back to exact patch equivalence between the entire
--- claimed change and a bounded first-parent suffix ending at the landed
--- commit. The suffix search is what admits a multi-commit rebase rather
--- than checking only a one-commit squash.
---
--- The caller must fetch the landed history first. Gitboard neither fetches
--- it nor asks a provider whether an external change merged.
--- @param root string The local product repository
--- @param claim_base string Base commit captured by the claim
--- @param accepted string Commit named by the accept verdict
--- @param landed string Landed commit supplied at completion
--- @return string | nil Canonical landed commit
--- @return string Error message
local function verify_landing(root: string, claim_base: string,
    accepted: string, landed: string): string | nil, string
  local lineage, verr = verify_lineage(root, claim_base, accepted)
  if lineage == nil then return nil, verr end
  local accepted_full, base_full = lineage.head, lineage.base
  local landed_full, lerr = commit_id(root, landed)
  if landed_full == nil then return nil, lerr end

  local preserved, aerr = is_ancestor(root, accepted_full, landed_full)
  if aerr ~= "" then return nil, aerr end
  if preserved then return landed_full, "" end

  local chain_run, perr = git(root, {"rev-list", "--first-parent",
      "--max-count=257", landed_full})
  if chain_run == nil then return nil, perr end
  if not chain_run.ok then
    return nil, ("cannot inspect landed first-parent history: %s")
    :format(chain_run.stderr)
  end
  local chain: {string} = {}
  for sha in chain_run.stdout:gmatch("([0-9a-fA-F]+)") do
    chain[#chain + 1] = sha:lower()
  end
  if #chain < 2 then
    return nil, ("landed commit %s has no first parent for patch verification")
    :format(landed_full)
  end
  local wanted, werr = exact_patch(root, base_full, accepted_full)
  if wanted == nil then return nil, werr end
  for n = 2, #chain do
    local got, gerr = exact_patch(root, chain[n], landed_full)
    if got == nil and not gerr:find("has no content patch", 1, true) then
      return nil, gerr
    end
    if wanted == got then return landed_full, "" end
  end
  local bounded = ""
  if #chain == 257 then bounded = " in its latest 256 first-parent commits" end
  return nil, ("landed commit %s neither contains accepted commit %s nor "
    .. "has its exact content patch%s"):format(landed_full, accepted_full, bounded)
end

local record commit_evidence
  commit_id: function(root: string, given: string): string | nil, string
  verify_lineage: function(root: string, claim_base: string,
  head: string): Lineage | nil, string
  verify_landing: function(root: string, claim_base: string,
  accepted: string, landed: string): string | nil, string
end

local M: commit_evidence = {
  commit_id = commit_id,
  verify_lineage = verify_lineage,
  verify_landing = verify_landing,
}

return M
