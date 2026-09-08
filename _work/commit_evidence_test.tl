#!/usr/bin/env cosmic
-- Commit-only handover, verdict and completion checks over a hermetic local
-- product repository. No remote exists in this fixture, proving every path is
-- local Git inspection.
local check = require("cosmic.check")
local child = require("cosmic.child")
local evidence = require("_work.commit_evidence")
local env = require("cosmic.env")
local fs = require("cosmic.fs")

local tmpdir = os.getenv("TEST_TMPDIR") or "/tmp"

local hermetic_config < const > = fs.join(tmpdir,
  "commit-evidence-gitconfig-empty")
assert(fs.write(hermetic_config, ""))
assert(env.set("GIT_CONFIG_GLOBAL", hermetic_config))
assert(env.set("GIT_CONFIG_NOSYSTEM", "1"))

local function git(root: string, args: {string}, stdin?: string): string
  local argv: {string} = {"git", "-c", "user.email=test@example.com",
    "-c", "user.name=test"}
  for _, value in ipairs(args) do argv[#argv + 1] = value end
  local r = check.must(child.run(argv, {cwd = root, stdin = stdin or ""}))
  assert(r.ok, "git " .. table.concat(args, " ") .. " failed: " .. r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

local function commit_file(root: string, name: string, content: string,
    message: string): string
  assert(fs.write(fs.join(root, name), content))
  git(root, {"add", name})
  git(root, {"commit", "-q", "-m", message})
  return git(root, {"rev-parse", "HEAD"})
end

--- A repository with one base, a two-commit accepted change, a squash of that
--- change onto another first parent, and a genuinely different landing.
local function product(name: string): string, string, string, string, string
  local root = fs.join(tmpdir, "commit-evidence-" .. name)
  assert(fs.remove_all(root))
  assert(fs.make_dirs(root))
  git(root, {"init", "-q"})
  git(root, {"checkout", "-q", "-b", "main"})
  local base = commit_file(root, "main.txt", "base\n", "base")
  git(root, {"checkout", "-q", "-b", "work"})
  commit_file(root, "main.txt", "base\nchange one\n", "one")
  local accepted = commit_file(root, "second.txt", "change two\n", "two")

  git(root, {"checkout", "-q", "main"})
  local parent = commit_file(root, "unrelated.txt", "unrelated\n", "other work")
  -- Apply the accepted range as one squash commit onto a first parent that is
  -- newer than the recorded claim base.
  local diff_run = check.must(child.run(
      {"git", "diff", "--binary", base, accepted, "--"}, {cwd = root}))
  assert(diff_run.ok, "git diff failed: " .. diff_run.stderr)
  local applied = check.must(child.run({"git", "apply", "--index"},
      {cwd = root, stdin = diff_run.stdout}))
  assert(applied.ok, "git apply failed: " .. applied.stderr)
  git(root, {"commit", "-q", "-m", "squash landing"})
  local squash = git(root, {"rev-parse", "HEAD"})

  git(root, {"reset", "-q", "--hard", parent})
  local different = commit_file(root, "main.txt", "base\na different change\n",
    "different landing")
  return root, base, accepted, squash, different
end

local function test_commit_ids_are_local_commit_objects_only()
  local root, base = product("objects")
  local full = check.must(evidence.commit_id(root, base:sub(1, 12)))
  check.equal(full, base, "an unambiguous commit prefix canonicalizes")
  assert(evidence.commit_id(root, "HEAD") == nil, "refs are not evidence")
  assert(evidence.commit_id(root, base .. "^1") == nil,
    "revision expressions are not evidence")
  assert(evidence.commit_id(root, "deadbeef") == nil,
    "an absent hexadecimal id is refused")
  local blob = git(root, {"hash-object", "main.txt"})
  assert(evidence.commit_id(root, blob) == nil, "a blob id is not a commit id")
end

local function test_verdict_head_must_descend_from_the_claim_base()
  local root, base, accepted, _, different = product("lineage")
  local lineage, err = evidence.verify_lineage(root, base, accepted)
  assert(lineage ~= nil and lineage.head == accepted
    and lineage.base == base, err)
  local bad, berr = evidence.verify_lineage(root, accepted, different)
  assert(bad == nil and berr:find("does not descend", 1, true) ~= nil, berr)
end

local function test_history_preserving_landing_passes_by_ancestry()
  local root, base, accepted = product("ancestry")
  local landed = git(root, {"checkout", "-q", "work"})
  landed = commit_file(root, "after.txt", "after\n", "landed after accepted")
  local got, err = evidence.verify_landing(root, base, accepted, landed)
  assert(got == landed, err)
end

local function test_squash_landing_passes_by_exact_patch()
  local root, base, accepted, squash = product("squash")
  local got, err = evidence.verify_landing(root, base, accepted, squash)
  assert(got == squash, err)
end

local function test_multi_commit_rebase_passes_by_aggregate_exact_patch()
  local root, base, accepted = product("rebase")
  git(root, {"checkout", "-q", "main"})
  local parent = git(root, {"rev-parse", "HEAD"})
  -- Reproduce the two accepted commits with new commit ids on the newer
  -- first-parent line. Neither rebased commit is the accepted commit's
  -- descendant, and the landed suffix contains two commits.
  assert(fs.write(fs.join(root, "main.txt"), "base\nchange one\n"))
  git(root, {"add", "main.txt"})
  git(root, {"commit", "-q", "-m", "rebased one"})
  local landed = commit_file(root, "second.txt", "change two\n", "rebased two")
  assert(git(root, {"rev-list", "--count", parent .. ".." .. landed}) == "2")
  local got, err = evidence.verify_landing(root, base, accepted, landed)
  assert(got == landed, err)
end

local function test_whitespace_changed_landing_is_not_equivalent()
  local root, base, accepted = product("whitespace")
  git(root, {"checkout", "-q", "main"})
  assert(fs.write(fs.join(root, "main.txt"), "base\nchange  one\n"))
  git(root, {"add", "main.txt"})
  git(root, {"commit", "-q", "-m", "similar but not exact"})
  local landed = commit_file(root, "second.txt", "change two\n", "second")
  local got, err = evidence.verify_landing(root, base, accepted, landed)
  assert(got == nil and err:find("exact content patch", 1, true) ~= nil, err)
end

local function test_a_different_landing_is_refused()
  local root, base, accepted, _, different = product("different")
  local got, err = evidence.verify_landing(root, base, accepted, different)
  assert(got == nil and err:find("neither contains", 1, true) ~= nil, err)
end

local function test_patch_fallback_requires_a_first_parent()
  local root, base, accepted = product("root")
  local orphan = fs.join(tmpdir, "commit-evidence-orphan")
  assert(fs.remove_all(orphan))
  assert(fs.make_dirs(orphan))
  git(orphan, {"init", "-q"})
  local landed = commit_file(orphan, "main.txt", "base\nchange one\n", "root")
  -- Put the unrelated root object into the product object database without a
  -- remote or network operation.
  local bundle = fs.join(tmpdir, "commit-evidence-orphan.bundle")
  git(orphan, {"bundle", "create", bundle, "HEAD"})
  git(root, {"fetch", bundle, "HEAD"})
  local got, err = evidence.verify_landing(root, base, accepted, landed)
  assert(got == nil and err:find("has no first parent", 1, true) ~= nil, err)
end
