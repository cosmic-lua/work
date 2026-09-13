--- Cross-item path collisions: which OTHER open items name the same
--- file under their `## Change` heading as a given item does — the
--- fact `gitboard show` and `gitboard next` surface so an orchestrator
--- does not have to `show` every pullable item by hand and compare
--- specs by eye to find two that touch the same file.
---
--- `paths_named` is the pure text extraction, checked against the
--- real tree this process runs from (relative paths resolve against
--- the working directory, which is the repo root for every normal
--- invocation and for the test runner alike) — a token that is not an
--- actual file is not a path, whatever it looks like. `collisions`,
--- `lines`, and `inline` build on it plus a map of already-read spec
--- bodies, the same shape `_work.gitview`'s `read_specs` produces —
--- this module does no store I/O of its own; the `cmd_*` callers own
--- that, per the read-verb convention the rest of `_work` follows.
---
--- `headroom_lines` reuses `raw_paths_named` — the unfiltered sibling
--- of `paths_named` — for second and third, unrelated questions about
--- the same Change section: not whether another item also names a
--- path, but whether the token names a real file at all, and if so
--- whether that file has room left under the 500-line cap `--check
--- lint` enforces. Unlike `paths_named`, a repo-relative token here
--- resolves at a KNOWN COMMIT of the item's OWN `repo` — the item's
--- recorded claim base, else that repository's default-branch tip — in
--- a caller-supplied checkout of it, never this process's working
--- directory and never any checkout's working tree: an item can be
--- `show`n from any checkout, including one for a different repo
--- entirely, and `paths_named`'s cwd-relative convention would read
--- every one of that OTHER repo's real files as absent, while a
--- working-tree read would answer differently depending on which branch
--- the checkout happens to be parked on. A `## Change`
--- naming a path its own repo's checkout does not have is a spec bug a
--- spec bar cannot mechanically refuse (the bar's "measured, not
--- inferred" rule covers counts and behaviour, not path existence), so
--- it is a warning, never a refusal — the same `--force`-free bar every
--- other line in `overlap.lines` already is — surfaced on `show` so a
--- refiner sees a wrong path, or a builder or refiner sees a file
--- already tight against the cap, before either pays for it live,
--- mid-implementation, the way `wc -l` and `--check lint` otherwise
--- would.
local child = require("cosmic.child")
local fs = require("cosmic.fs")
local repoprofile = require("_work.repoprofile")
local spec = require("_work.spec")
local tail = require("_work.tail")

--- The file-length lint's own ceiling ([D39] in `cosmic-lua/cosmic`:
--- no prose exemption from it) — kept here rather than imported, since
--- no module in this tree computes line counts and the number itself
--- is the one this repo's own `.tl` files are already held to.
local FILE_CAP < const > = 500

--- How close to `FILE_CAP` counts as tight enough to warn about — wide
--- enough that a builder's own addition (the friction this exists to
--- catch ran 12-14 lines) still fits inside the margin most of the
--- time, narrow enough that a file with real room left stays quiet.
local WARN_MARGIN < const > = 20

--- The Ready-when command's hard cap: a hung command must never park
--- a `next` or `take` call indefinitely.
local READY_TIMEOUT_MS < const > = 10000

--- Whether `token` has a path's shape: only path-safe characters, at
--- least one `/`, and an extension on its last segment. Rules out a
--- verb or flag caught in backticks for other reasons (`` `take` ``,
--- `` `--why` ``) and a dotted module name (`` `_work.gitverbs` ``,
--- no `/`), without ruling out a multi-segment path
--- (`docs/decisions/d20-naming-charter.md`).
--- @param token string A backtick-quoted span
--- @return boolean True when it has a path's shape
local function looks_like_path(token: string): boolean
  if token:match("[^%w_%-%./]") then
    return false
  end
  if not token:find("/") then
    return false
  end
  local base = token:match("([^/]+)$")
  return base ~= nil and base:match("%.[%w_%-]+$") ~= nil
end

--- The non-blank lines under `spec_text`'s `## Change` heading (any
--- level, matched case-insensitively), joined — `_work.spec.sections`
--- narrowed to the one heading this module reads, so the section this
--- sees is byte-for-byte the section the spec bar sees. A subheading
--- inside Change is content, not a new section, so a path named under
--- a `### Files` is read here too; a thematic break (`---`) ends the
--- section the way it ends any other.
--- @param spec_text string An item's spec sidecar body
--- @return string The Change section's lines, "" when it has none
local function change_section(spec_text: string): string
  return spec.sections(spec_text)["change"] or ""
end

--- Every backtick-quoted, path-looking token in `spec_text`'s `##
--- Change` section, present in the tree or not — the raw extraction
--- `paths_named` and `headroom_lines` each filter differently.
--- Deduplicated, first-seen order.
--- @param spec_text string An item's spec sidecar body
--- @return {string} The path-shaped tokens its Change section names
local function raw_paths_named(spec_text: string): {string}
  local change = change_section(spec_text)
  local seen: {string: boolean} = {}
  local out: {string} = {}
  for token in change:gmatch("`([^`\n]+)`") do
    if looks_like_path(token) and not seen[token] then
      seen[token] = true
      out[#out + 1] = token
    end
  end
  return out
end

--- Every backtick-quoted, path-looking token in `spec_text`'s `##
--- Change` section that names a file actually present in the tree —
--- the filter that keeps a plausible-looking token (a stale path from
--- a rewritten plan, a path in prose about a FUTURE file) from
--- reading as a real collision. Deduplicated, first-seen order.
--- @param spec_text string An item's spec sidecar body
--- @return {string} The paths its Change section names
local function paths_named(spec_text: string): {string}
  local out: {string} = {}
  for _, token in ipairs(raw_paths_named(spec_text)) do
    if fs.is_present(token) then
      out[#out + 1] = token
    end
  end
  return out
end

--- `path`'s line count the way `wc -l` counts it — newlines, not
--- logical lines — the same measure the file-length lint reads, so a
--- count here never disagrees with what `--check lint` would say.
--- nil when `path` cannot be read, with the `fs.read` error alongside
--- (a present path can still be unreadable — a directory, say).
--- @param path string A path already known to be present (`fs.is_present`)
--- @return integer | nil The newline count, nil when unreadable
--- @return string The `fs.read` error, "" on success
local function line_count(path: string): integer | nil, string
  local text, rerr = fs.read(path)
  if text == nil then
    return nil, rerr
  end
  local n = 0
  for _ in text:gmatch("\n") do
    n = n + 1
  end
  return n, ""
end

--- The commit a repo-relative Change-section token is read at: the
--- item's recorded claim base when `checkout` holds that commit, else
--- the tip of the repository's default branch — the branch
--- `origin/HEAD` names when the checkout caches one, else the identity's
--- own convention (`master` for cosmopolitan, `main` for everything
--- else) — tried as the remote-tracking ref first and the local branch
--- second. No working tree is read and no remote is queried, so a
--- checkout parked on another branch or carrying uncommitted edits
--- answers the same question the same way.
--- @param checkout string A local checkout of the item's own `repo`, ""
--- when none is set up here
--- @param repo string The item's repo identity (`owner/name`)
--- @param base string The item's recorded claim base, "" when it has none
--- @return string The resolved commit id, "" when no candidate names a
--- commit in `checkout`
local function commit_at(checkout: string, repo: string, base: string): string
  if checkout == "" then
    return ""
  end
  local branch = repoprofile.default_base(checkout)
  if branch == "" then
    branch = repo:find("cosmopolitan", 1, true) ~= nil and "master" or "main"
  end
  local candidates: {string} = {
    "refs/remotes/origin/" .. branch, "refs/heads/" .. branch,
  }
  if base ~= "" then
    table.insert(candidates, 1, base)
  end
  for _, rev in ipairs(candidates) do
    local r = child.run({"git", "rev-parse", "--verify", "--quiet",
        rev .. "^{commit}"}, {cwd = checkout})
    if r ~= nil and r.ok then
      local id = (r.stdout:gsub("%s+$", ""))
      if id ~= "" then
        return id
      end
    end
  end
  return ""
end

--- `token`'s line count at `rev`, read out of `checkout`'s object
--- database rather than its working tree, the same `wc -l` measure
--- `line_count` takes on disk. nil with "" when `rev` carries no such
--- path at all; nil with a reason when the path is there but is not a
--- file (a directory, a submodule), which reads as `unreadable:` the
--- way an unreadable present path does.
--- @param checkout string A local checkout of the item's own `repo`
--- @param rev string The commit to read at
--- @param token string A repo-relative path
--- @return integer | nil The newline count, nil when missing or unreadable
--- @return string Why it is unreadable, "" when it is simply absent
local function blob_lines(checkout: string, rev: string,
    token: string): integer | nil, string
  local object = rev .. ":" .. token
  local kind = child.run({"git", "cat-file", "-t", object}, {cwd = checkout})
  if kind == nil or not kind.ok then
    return nil, ""
  end
  local what = (kind.stdout:gsub("%s+$", ""))
  if what ~= "blob" then
    return nil, ("%s at the resolved commit, not a file"):format(what)
  end
  local blob = child.run({"git", "cat-file", "blob", object}, {cwd = checkout})
  if blob == nil then
    return nil, "cannot read the object"
  end
  if not blob.ok then
    return nil, (blob.stderr:gsub("%s+$", ""))
  end
  local n = 0
  for _ in blob.stdout:gmatch("\n") do
    n = n + 1
  end
  return n, ""
end

--- The one line a path-shaped Change-section token earns, "" when it
--- earns none: `absent: ...` for a token naming no real file where it
--- resolves (`o/` included — a spec naming a build output must name the
--- one the build actually makes), `unreadable: ...` for a path that is
--- there but cannot be read as text (a directory, say), and `tight: ...`
--- for a readable path already within `WARN_MARGIN` lines of `FILE_CAP`.
---
--- An absolute token resolves against the filesystem root: nothing about
--- it depends on which repo the item names, or on any commit. A
--- repo-relative token (the ordinary spelling: `_work/gitshow.tl`, not
--- `/abs/.../_work/gitshow.tl`) resolves at `rev` in `checkout` — never
--- against this process's own working directory, which may belong to a
--- different repo entirely, and never against a working tree, whose
--- answer moves with whichever branch someone left the checkout on. A
--- relative token with no commit to resolve against reads `not
--- checked: ...` instead of guessing either way.
--- @param token string A path-shaped token from the Change section
--- @param checkout string A local checkout of the item's own `repo`
--- @param rev string `commit_at`'s resolved commit, "" when there is none
--- @param repo_label string The repo identity named in `not checked`
--- @return string The line, "" when the token earns none
local function headroom_line(token: string, checkout: string, rev: string,
    repo_label: string): string
  local absent = ("absent: `%s` does not exist in the tree"):format(token)
  local n: integer | nil = nil
  local rerr = ""
  if fs.is_absolute(token) then
    if not fs.is_present(token) then
      return absent
    end
    n, rerr = line_count(token)
  elseif rev == "" then
    return ("not checked: `%s` (no checkout of %s here)")
    :format(token, repo_label)
  else
    n, rerr = blob_lines(checkout, rev, token)
    if n == nil and rerr == "" then
      return absent
    end
  end
  if n == nil then
    return ("unreadable: `%s`: %s"):format(token, rerr)
  end
  if FILE_CAP - n > WARN_MARGIN then
    return ""
  end
  return ("tight: `%s` is %d/%d lines, %d left before the cap —"
    .. " plan a repacking or split before pulling"):format(
    token, n, FILE_CAP, FILE_CAP - n)
end

--- One line per path-shaped token in `body`'s Change section that needs
--- a refiner's or builder's attention before a pull, in
--- `raw_paths_named` order — `headroom_line`'s own rules, over the
--- commit `commit_at` resolves once for the whole section.
--- @param body string An item's spec sidecar body
--- @param checkout string A local checkout of the item's own `repo`
--- (`_work.repository_map.resolve` — the same lookup `gitboard
--- worktree` already uses to find a repo's checkout), "" when none is
--- set up here
--- @param repo string The item's repo identity, named in the `not
--- checked` fallback; "" reads as "its repo"
--- @param base string The item's recorded claim base, "" when it has
--- none — the commit relative tokens are read at, ahead of the
--- repository's default-branch tip
--- @return {string} The lines, possibly empty
local function headroom_lines(body: string, checkout: string, repo: string,
    base: string): {string}
  local out: {string} = {}
  local repo_label = repo ~= "" and repo or "its repo"
  local rev = commit_at(checkout, repo, base)
  for _, token in ipairs(raw_paths_named(body)) do
    local line = headroom_line(token, checkout, rev, repo_label)
    if line ~= "" then
      out[#out + 1] = line
    end
  end
  return out
end

--- Whether `body`'s `## Change` section names a fact this pull is not
--- ready for yet: the first sentence beginning `Ready when:` that
--- carries at least two backtick spans names a command (the first
--- span) and the output that means ready (the second). The command
--- runs from this process's own working directory with its stdout
--- captured and trimmed and its stderr left unread; a run over
--- `READY_TIMEOUT_MS` is killed and counts as a mismatch rather than
--- parking the caller.
---
--- A sentence with fewer than two spans is prose ABOUT the
--- convention, never a command to run — the doctrine page's own
--- explanation of `Ready when:` carries none, and this never spawns
--- for it. No such sentence at all reads the same way: nothing to
--- check.
--- @param body string An item's spec sidecar body
--- @return string | nil "not ready: ..." on a mismatch; nil when the
--- trimmed stdout matches, when there is no such sentence, or the
--- sentence names fewer than two spans
local function ready_when(body: string): string | nil
  local change = change_section(body)
  local from = change:find("Ready when:", 1, true)
  if from == nil then
    return nil
  end
  local rest = change:sub(from)
  local stop = rest:find("%.%s") or rest:find("%.$")
  local sentence = stop and rest:sub(1, stop) or rest
  local cmd: string = nil
  local want: string = nil
  local n = 0
  for token in sentence:gmatch("`([^`\n]+)`") do
    n = n + 1
    if n == 1 then
      cmd = token
    elseif n == 2 then
      want = token
      break
    end
  end
  if n < 2 then
    return nil
  end
  local argv: {string} = {}
  for word in cmd:gmatch("%S+") do
    argv[#argv + 1] = word
  end
  if #argv == 0 then
    return nil
  end
  local h, herr = child.start(argv)
  if h == nil then
    return ("not ready: `%s` could not run: %s; ready means `%s`"):format(
      cmd, herr, want)
  end
  local r, _werr = h:wait(READY_TIMEOUT_MS)
  local got: string
  local shown: string
  if r == nil then
    local _sok, _serr = h:stop()
    local _r2, _werr2 = h:wait()
    got = ""
    shown = ("timed out after %dms"):format(READY_TIMEOUT_MS)
  else
    got = (r.stdout or ""):gsub("^%s+", ""):gsub("%s+$", "")
    shown = got:match("^[^\n]*")
    if shown == "" then
      shown = ("exit %d"):format(r.code or -1)
    end
  end
  if got == want then
    return nil
  end
  return ("not ready: `%s` printed `%s`; ready means `%s`"):format(
    cmd, shown, want)
end

--- One colliding item: its id and the paths it shares with the item
--- being checked.
local record Collision
  id: string
  paths: {string}
end

--- Every OTHER item in `bodies` whose Change-section paths intersect
--- `id`'s, sorted by id (creation order) for a deterministic render.
--- Empty when `id` itself names nothing, without inspecting `bodies`
--- any further.
--- @param id string The item to check
--- @param bodies {string: string} Spec sidecar body by id, open items only
--- @return {Collision} Colliding items, each with its shared paths
local function collisions(id: string, bodies: {string: string}): {Collision}
  local out: {Collision} = {}
  local mine: {string: boolean} = {}
  for _, p in ipairs(paths_named(bodies[id] or "")) do
    mine[p] = true
  end
  if next(mine) == nil then
    return out
  end
  local others: {string} = {}
  for other_id in pairs(bodies) do
    if other_id ~= id then
      others[#others + 1] = other_id
    end
  end
  table.sort(others)
  for _, other_id in ipairs(others) do
    local shared: {string} = {}
    for _, p in ipairs(paths_named(bodies[other_id] or "")) do
      if mine[p] then
        shared[#shared + 1] = p
      end
    end
    if #shared > 0 then
      out[#out + 1] = {id = other_id, paths = shared}
    end
  end
  return out
end

--- One `overlaps: <handle> on <path>[, <path>...]` line per colliding
--- item — what `show` prints, an empty list when nothing collides.
--- @param id string The item to check
--- @param bodies {string: string} Spec sidecar body by id, open items only
--- @return {string} The lines, possibly empty
local function lines(id: string, bodies: {string: string}): {string}
  local out: {string} = {}
  for _, c in ipairs(collisions(id, bodies)) do
    out[#out + 1] = ("overlaps: %s on %s"):format(tail.handle(c.id),
      table.concat(c.paths, ", "))
  end
  return out
end

--- The same annotation as `lines`, joined onto one line for `next`'s
--- `or: pull` alternates — "" when nothing collides, so a caller
--- appends it only when it applies.
--- @param id string The item to check
--- @param bodies {string: string} Spec sidecar body by id, open items only
--- @return string The joined annotation, "" when none
local function inline(id: string, bodies: {string: string}): string
  return table.concat(lines(id, bodies), "; ")
end

local record overlap
  type Collision = Collision
  raw_paths_named: function(spec_text: string): {string}
  paths_named: function(spec_text: string): {string}
  collisions: function(id: string, bodies: {string: string}): {Collision}
  lines: function(id: string, bodies: {string: string}): {string}
  inline: function(id: string, bodies: {string: string}): string
  headroom_lines: function(body: string, checkout: string, repo: string,
  base: string): {string}
  ready_when: function(body: string): string | nil
end

local M: overlap = {
  raw_paths_named = raw_paths_named,
  paths_named = paths_named,
  collisions = collisions,
  lines = lines,
  inline = inline,
  headroom_lines = headroom_lines,
  ready_when = ready_when,
}

return M
