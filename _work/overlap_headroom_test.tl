#!/usr/bin/env cosmic
-- The spec bar's path check: `overlap.headroom_lines`, and the
-- `absent:`/`unreadable:`/`tight:`/`not checked:` lines `show` prints
-- from it.
--
-- Split out of `_work/overlap_test.tl`: a repo-relative token now
-- resolves at a COMMIT of the item's own repository rather than in any
-- working tree, so every case here needs a real git checkout with real
-- commits in it, which the collision tests next door do not.

local check = require("cosmic.check")
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local fixture = require("_work.fixture")
local gitspec = require("_work.gitspec")
local overlap = require("_work.overlap")
local show = require("_work.gitshow")
local store = require("_work.store")
local storewrite = require("_work.storewrite")

local init_state_repo = fixture.init_state_repo
local root_with_leaf = fixture.root_with_leaf

--- Set a custom spec sidecar meeting the ready bar, through the spec
--- verb, so a test can put a path in `## Change` for the bar to check.
--- @param s store.Store The store
--- @param id string The item whose spec is set
--- @param body string The spec markdown
local function write_spec(s: store.Store, id: string, body: string)
  local path = fs.join(fixture.tmpdir, "headroom-spec-" .. id .. ".md")
  assert(fs.write(path, body))
  assert(gitspec.cmd_spec(s, id, path) == 0, "spec should be accepted")
end

--- Write a file of exactly `n` lines, the way `wc -l` counts them: `n`
--- newline characters, matching `overlap.line_count`'s own measure.
--- @param path string Where to write it
--- @param n integer How many lines
local function write_n_lines(path: string, n: integer)
  local rows: {string} = {}
  for i = 1, n do
    rows[i] = "x"
  end
  assert(fs.write(path, table.concat(rows, "\n") .. "\n"))
end

--- Run one git command in `root` and return its trimmed stdout —
--- `fixture.git`'s failing-loudly behaviour, for the calls whose output
--- a test needs (a commit id).
--- @param root string The checkout to run in
--- @param args {string} The git arguments
--- @return string The trimmed stdout
local function git_out(root: string, args: {string}): string
  local argv: {string} = {"git", "-c", "user.email=test@example.com",
    "-c", "user.name=test"}
  for _, value in ipairs(args) do
    argv[#argv + 1] = value
  end
  local r = check.must(child.run(argv, {cwd = root}))
  assert(r.ok, "git " .. table.concat(args, " ") .. " failed: " .. r.stderr)
  return (r.stdout:gsub("%s+$", ""))
end

--- A scratch checkout of some OTHER repository: a fresh `main` whose
--- one commit carries each named path at the given line count. `main`
--- by name because a checkout with no `origin/HEAD` cached falls back
--- to the default branch a repo identity implies, which is what a real
--- mapped checkout resolves through.
--- @param name string A per-test suffix, so no two tests share a path
--- @param files {string: integer} Path relative to the root, line count
--- @return string The checkout root
--- @return string The seed commit's id
local function seeded_repo(name: string, files: {string: integer}): string, string
  local root = fs.join(fixture.tmpdir, "headroom-repo-" .. name)
  assert(fs.remove_all(root) and fs.make_dirs(root))
  fixture.git(root, {"init", "-q", "-b", "main"})
  for path, n in pairs(files) do
    assert(fs.make_dirs(fs.dirname(fs.join(root, path))))
    write_n_lines(fs.join(root, path), n)
  end
  fixture.git(root, {"add", "-A"})
  fixture.git(root, {"commit", "-q", "-m", "seed"})
  return root, git_out(root, {"rev-parse", "HEAD"})
end

--- Run show.cmd_show and capture exactly what it prints via print() —
--- the swap-and-restore pattern the other verb tests use.
--- @param s store.Store The store
--- @param id string The item to show
--- @return integer cmd_show's exit code
--- @return string Every print()'d line, newline-joined
local function show_and_capture(s: store.Store, id: string): integer, string
  local old_print = _G.print
  local lines: {string} = {}
  _G.print = function(...: any)
    local parts: {string} = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring((select(i, ...)))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(show.cmd_show, s, id)
  _G.print = old_print
  if not ok then
    error(result, 0)
  end
  return result, table.concat(lines, "\n")
end

--- Point `s`'s repository map at `root` and give the item that repo
--- identity, the ordinary `gitboard.repository` configuration a session
--- sets up by hand.
--- @param s store.Store The store
--- @param id string The item
--- @param repo string The repo identity to record on it
--- @param root string The local checkout to map that identity to
local function map_repo(s: store.Store, id: string, repo: string, root: string)
  fixture.git(s.root, {"config", "--local", "--add", "gitboard.repository",
      repo .. "=" .. root})
  local it = check.must(store.load(s, id))
  it.repo = repo
  assert(storewrite.save(s, it, "set repo"))
end

-- `headroom_lines` warns right at the margin: a file with exactly
-- `WARN_MARGIN` lines of headroom left (480/500) is already tight
-- enough to flag. The path is absolute, so it resolves the same way
-- regardless of `checkout` — this test passes `fixture.tmpdir` anyway,
-- the way a real caller always has SOME checkout in hand.
local function test_headroom_lines_warns_at_the_margin()
  local path = fs.join(fixture.tmpdir, "overlap-headroom-480.tl")
  write_n_lines(path, 480)
  local body = ("## Change\nTouch `%s`.\n"):format(path)
  local lines = overlap.headroom_lines(body, fixture.tmpdir, "acme/widgets", "")
  assert(#lines == 1, table.concat(lines, "; "))
  assert(lines[1]:find("`" .. path .. "` is 480/500 lines, 20 left", 1, true),
    lines[1])
end

-- One line of MORE headroom (479/500, 21 lines left) is outside the
-- margin and stays quiet — the boundary the margin actually draws.
local function test_headroom_lines_silent_with_room_to_spare()
  local path = fs.join(fixture.tmpdir, "overlap-headroom-479.tl")
  write_n_lines(path, 479)
  local body = ("## Change\nTouch `%s`.\n"):format(path)
  local lines = overlap.headroom_lines(body, fixture.tmpdir, "acme/widgets", "")
  assert(#lines == 0, table.concat(lines, "; "))
end

-- A Change section naming a path the item's own repository does not
-- carry at the resolved commit (a plain typo, or a stale path from a
-- rewritten plan) is exactly the gap a spec bar cannot mechanically
-- refuse — `headroom_lines` names it rather than staying silent.
local function test_headroom_lines_flags_an_absent_path()
  local root = seeded_repo("absent", {["src/present.tl"] = 5})
  local body = "## Change\nTouch `some/other/repo/big_file.tl`.\n"
  local lines = overlap.headroom_lines(body, root, "acme/widgets", "")
  assert(#lines == 1, table.concat(lines, "; "))
  assert(lines[1] == "absent: `some/other/repo/big_file.tl`"
    .. " does not exist in the tree", lines[1])
end

-- No checkout of the item's own repo is available here at all (`show`
-- run from a checkout of a DIFFERENT repo, with no local mapping
-- configured for this one) — a relative token reads `not checked`,
-- never `absent`: this process has no tree to resolve it against
-- either way, and guessing wrong is worse than saying so.
local function test_headroom_lines_not_checked_without_a_checkout()
  local body = "## Change\nTouch `_work/gitshow.tl`.\n"
  local lines = overlap.headroom_lines(body, "", "acme/other", "")
  assert(#lines == 1, table.concat(lines, "; "))
  assert(lines[1] == "not checked: `_work/gitshow.tl`"
    .. " (no checkout of acme/other here)", lines[1])
end

-- `fs.is_present` passes a directory, but `fs.read` cannot read one as
-- text — `line_count`'s error slot rides along as an `unreadable:`
-- line, distinct from a path missing outright.
local function test_headroom_lines_flags_an_unreadable_present_path()
  local path = fs.join(fixture.tmpdir, "overlap-headroom.tl")
  assert(fs.make_dirs(path))
  local body = ("## Change\nTouch `%s`.\n"):format(path)
  local lines = overlap.headroom_lines(body, fixture.tmpdir, "acme/widgets", "")
  assert(#lines == 1, table.concat(lines, "; "))
  assert(lines[1]:find("unreadable: `" .. path .. "`: ", 1, true), lines[1])
end

-- A directory at the resolved commit reads the same way a directory on
-- disk does: present, but not a file anything can count lines in. A
-- token only reaches this branch when it has a path's shape, so the
-- directory here carries an extension the way `src/pkg.tl/` would.
local function test_headroom_lines_flags_a_directory_at_the_commit()
  local root = seeded_repo("directory", {["src/pkg.tl/inner.txt"] = 5})
  local lines = overlap.headroom_lines("## Change\nTouch `src/pkg.tl`.\n",
    root, "acme/widgets", "")
  assert(#lines == 1, table.concat(lines, "; "))
  assert(lines[1]:find("unreadable: `src/pkg.tl`: tree at the resolved commit",
      1, true), lines[1])
end

-- Every path-shaped Change-section token that names no real file is
-- named `absent: ...` — including one under `o/`, the build output
-- directory a builder loses time to when a spec names a path the build
-- does not actually make (cosmic#1752's `o/embed/cosmic/.docs/` vs. the
-- path the build made instead). A present path is named by neither.
local function test_headroom_lines_names_absent_paths_including_under_o()
  local root = seeded_repo("under-o", {["src/present.tl"] = 5})
  local present = fs.join(fixture.tmpdir, "overlap-present.tl")
  write_n_lines(present, 5)
  local absent = fs.join(fixture.tmpdir, "overlap-absent-nowhere.tl")
  local absent_o = "o/overlap-absent-nowhere-under-o.tl"
  local body = ("## Change\nTouch `%s`, `%s`, and `%s`.\n"):format(
    present, absent, absent_o)

  local lines = overlap.headroom_lines(body, root, "acme/widgets", "")
  assert(#lines == 2, table.concat(lines, "; "))
  assert(lines[1] == ("absent: `%s` does not exist in the tree"):format(absent),
    lines[1])
  assert(lines[2] == ("absent: `%s` does not exist in the tree"):format(absent_o),
    lines[2])
  for _, line in ipairs(lines) do
    assert(not line:find(present, 1, true),
      "the present path is not named: " .. line)
  end
end

-- The check reads the item's repository at a COMMIT, never a working
-- tree: a path the resolved commit carries is not absent, whatever the
-- checkout happens to hold right now — parked on another branch,
-- mid-edit, or with the file deleted outright, as here. The `tight:`
-- line proves the blob was actually read, not merely skipped.
local function test_headroom_lines_reads_the_commit_not_the_working_tree()
  local root = seeded_repo("worktree-drift", {["src/tight.tl"] = 480})
  assert(fs.remove(fs.join(root, "src/tight.tl")))
  local lines = overlap.headroom_lines("## Change\nTouch `src/tight.tl`.\n",
    root, "acme/widgets", "")
  assert(#lines == 1, table.concat(lines, "; "))
  assert(lines[1]:find("tight: `src/tight.tl` is 480/500", 1, true), lines[1])
end

-- The mirror image: a file only the working tree has, never committed,
-- is genuinely absent at the resolved commit and says so. A spec naming
-- a path that exists nowhere the change will be read from is the typo
-- this line exists to catch.
local function test_headroom_lines_absent_when_only_in_the_working_tree()
  local root = seeded_repo("uncommitted", {["src/present.tl"] = 5})
  write_n_lines(fs.join(root, "src/new.tl"), 5)
  local lines = overlap.headroom_lines("## Change\nAdd `src/new.tl`.\n",
    root, "acme/widgets", "")
  assert(#lines == 1, table.concat(lines, "; "))
  assert(lines[1] == "absent: `src/new.tl` does not exist in the tree",
    lines[1])
end

-- The item's recorded claim base is the commit, ahead of the default
-- branch's tip: a builder's spec is about the tree it was written
-- against, so a file the base carries and main has since dropped is
-- measured, not reported absent. With no base recorded, the same
-- checkout answers from the default-branch tip instead.
local function test_headroom_lines_prefers_the_recorded_claim_base()
  local root, base = seeded_repo("claim-base", {["src/tight.tl"] = 480})
  assert(fs.remove(fs.join(root, "src/tight.tl")))
  fixture.git(root, {"commit", "-q", "-am", "drop it"})
  local body = "## Change\nTouch `src/tight.tl`.\n"

  local at_base = overlap.headroom_lines(body, root, "acme/widgets", base)
  assert(#at_base == 1 and at_base[1]:find("tight: `src/tight.tl` is 480/500",
      1, true), table.concat(at_base, "; "))

  local at_tip = overlap.headroom_lines(body, root, "acme/widgets", "")
  assert(#at_tip == 1, table.concat(at_tip, "; "))
  assert(at_tip[1] == "absent: `src/tight.tl` does not exist in the tree",
    at_tip[1])
end

-- `show` prints the same `tight:` line for a real item whose spec
-- names a file already within the margin — the warning a refiner or
-- builder sees before a pull, not after hitting the lint cap live.
local function test_show_surfaces_a_tight_change_section_path()
  local s = init_state_repo("headroom")
  local _root, first = root_with_leaf(s)
  local path = fs.join(fixture.tmpdir, "overlap-headroom-show.tl")
  write_n_lines(path, 480)
  local body = ("## Change\nTouch `%s`.\n"):format(path)
  write_spec(s, first, body)

  local _, out = show_and_capture(s, first)
  assert(out:find("tight: `" .. path .. "` is 480/500", 1, true),
    "the tight file is named: " .. out)
end

-- An item's `repo` names a checkout OTHER than the one this process
-- runs from, mapped through the ordinary `gitboard.repository` config,
-- and its spec names a relative path that exists only in that other
-- checkout. `show` resolves through the map, so the path is not
-- `absent` — the false positive a "this board's own repo, read from a
-- product checkout" `show` would otherwise print for every file of it.
local function test_show_resolves_a_relative_path_against_the_items_own_repo()
  local s = init_state_repo("otherrepo")
  local _root, first = root_with_leaf(s)
  local other_root = seeded_repo("other", {["src/only_here.tl"] = 480})
  map_repo(s, first, "acme/other", other_root)
  write_spec(s, first, "## Change\nTouch `src/only_here.tl`.\n")

  local _, out = show_and_capture(s, first)
  assert(not out:find("absent:", 1, true),
    "a file present in the item's own repo is not absent: " .. out)
  assert(out:find("tight: `src/only_here.tl` is 480/500", 1, true),
    "and it is measured in that checkout: " .. out)
end
