--- The spec bar's grammar: the one heading a spec sidecar must
--- carry — what to build — and whether a given body carries it. Also
--- the read-access half of the bar: a repository the spec's own text
--- reaches (a `github.com` URL, wherever it sits) that is not the
--- item's own `repo` field must be named under a `## Access` heading,
--- so a claim or a review that cannot reach it bounces at the bar
--- instead of after a pull.
---
--- There is no Acceptance section, because acceptance is not
--- per-item: the CI gate passing is the one definition of done every
--- item shares, and proof specific to a change rides the DIFF as a
--- test or ratchet the gate runs — a gate outlives the sidecar that
--- asked for it. The bar checks only what a machine can check
--- honestly: whether the Change decides enough is the puller's
--- judgment (a wrong call comes back as a question the item gets
--- blocked on, or as a release),
--- and optional prose sections ride along untouched. Whether a
--- declared repository is actually reachable is the same kind of
--- judgment — this only checks that the requirement is STATED.
---
--- It also names a spec's REVISION, because the sidecar is half of
--- what a review judges: the diff is the other half, and a rework
--- that answers a bounce by rewriting the spec moves this half alone.
local hash = require("cosmic.hash")
local itemtree = require("_work.itemtree")

--- The headings a spec must carry.
local READY_SECTIONS < const >: {string} = {
  "Change",
}

--- The heading a spec declares its out-of-self read access under.
local ACCESS < const > = "access"

--- The lines gathered under each heading in `body`, keyed by the
--- lower-cased heading text — the section-scanning `ready_gaps` and
--- `declared_repos` both stand on. A heading counts at any level
--- ("## Change", "# change"), matched case-insensitively, and closes
--- the open section only when its own level is less than or equal to
--- that section's: a DEEPER heading is content, so its own line and
--- everything under it belong to the section it sits under, and a
--- `### Files` inside `## Change` never opens a section of its own.
---
--- A level-1 heading is the exception, because a sidecar is
--- `##`-sectioned: a lone `#` is the document's TITLE, not a
--- container. It opens a readable section like any other heading — a
--- spec that writes `# Change` is read — but nothing nests inside it,
--- so the next heading of any level closes it and `## Change` under
--- `# Item title` is the Change section rather than prose inside the
--- title. Without that floor a titled sidecar reads as having no
--- Change at all.
---
--- A thematic break (---) ends any section whatever its level, so a
--- footer appended below a break belongs to no heading.
--- @param body string The spec sidecar's markdown
--- @return {string: string} Heading text -> its non-blank lines, joined with "\n"
local function sections(body: string): {string: string}
  local out: {string: string} = {}
  local current: string = nil
  local level = 0
  for line in (body .. "\n"):gmatch("([^\n]*)\n") do
    local hashes, text = line:match("^(#+)%s+(.-)%s*$")
    if text and (current == nil or level == 1 or #hashes <= level) then
      current = text:lower()
      level = #hashes
    elseif line:match("^%s*%-%-%-+%s*$") then
      current = nil
      level = 0
    elseif current and line:match("%S") then
      out[current] = (out[current] or "") .. line .. "\n"
    end
  end
  return out
end

--- The code spans in `text` — inline `` `...` `` runs and fenced
--- ```...``` blocks — the only place a sweep's own pasted dry-run
--- output can honestly live: prose that merely mentions "applied" is
--- not evidence, a pasted command's own output is.
--- @param text string Any spec text
--- @return {string} Each span's inner text, in order
local function code_spans(text: string): {string}
  local out: {string} = {}
  for fence in text:gmatch("```(.-)```") do
    out[#out + 1] = fence
  end
  local without_fences = (text:gsub("```.-```", ""))
  for inline in without_fences:gmatch("`([^`\n]+)`") do
    out[#out + 1] = inline
  end
  return out
end

--- The gap a sweep-shaped Change leaves when its spec pastes no
--- dry-run evidence: `## Change` naming `--apply` or `--fix` needs a
--- fenced `rewrite:` or `applied` line somewhere in the spec — the
--- command's own dry-run output (the `applied`/`refused` line, or the
--- refusal), not only the `--find` count that named its sites. A
--- spec whose sweep command was never run at spec time is the wrong
--- turn this exists to catch.
--- @param body string The spec sidecar's markdown
--- @return {string} Zero or one gap
local function sweep_gaps(body: string): {string}
  local change = sections(body)["change"] or ""
  if not (change:find("%-%-apply%f[%A]") or change:find("%-%-fix%f[%A]")) then
    return {}
  end
  for _, span in ipairs(code_spans(body)) do
    if span:find("rewrite:", 1, true) or span:find("applied", 1, true) then
      return {}
    end
  end
  return {"Change names a sweep (--apply/--fix) with no pasted dry-run "
    .. "output — paste the command's own `rewrite:`/`applied` (or "
    .. "refusal) line, not only the --find count"}
end

--- Spec-bar lint: the gaps that keep a body from being buildable,
--- each as one readable line. A heading counts as filled only when at
--- least one non-blank line follows it before the next heading, so a
--- pasted template with hollow sections still fails.
--- @param body string The spec sidecar's markdown
--- @return {string} Gap descriptions, possibly empty
local function ready_gaps(body: string): {string}
  local filled = sections(body)
  local gaps: {string} = {}
  for _, name in ipairs(READY_SECTIONS) do
    if not (filled[name:lower()] or ""):match("%S") then
      gaps[#gaps + 1] = ("%s is missing or empty"):format(name)
    end
  end
  for _, gap in ipairs(sweep_gaps(body)) do
    gaps[#gaps + 1] = gap
  end
  return gaps
end

--- The `owner/repo` pairs a `github.com` URL in `text` names —
--- `https://github.com/owner/repo`, a bare `github.com/owner/repo`,
--- or the SSH `git@github.com:owner/repo` — normalized to lowercase
--- with a trailing `.git` or sentence-ending `.` stripped. The one
--- signal `reached_repos` and `declared_repos` both read: a URL is
--- unambiguous, where a bare `owner/repo` token is indistinguishable
--- from a module path (`cosmic/fs`) or a doc path (`docs/decisions`)
--- and would false-positive on nearly every spec in this repo.
--- @param text string Any spec text
--- @return {string} Repo slugs, in first-seen order, may repeat
local function github_urls(text: string): {string}
  local out: {string} = {}
  for owner, name in text:gmatch("github%.com[:/]([%w%-%.]+)/([%w%-%._]+)") do
    name = name:gsub("%.git$", ""):gsub("%.$", "")
    out[#out + 1] = (owner .. "/" .. name):lower()
  end
  return out
end

--- The repositories a spec's OWN text reaches, wherever a
--- `github.com` URL sits in it — a command in `## Change`, a citation
--- in `## Evidence`, a fixture in `## Acceptance`. This is "reaches",
--- not "needs": the item's own `repo` and any self-mention are not
--- filtered out here, because that judgment needs the item — see
--- `_work.gitready.undeclared_repos`.
--- @param body string The spec sidecar's markdown
--- @return {string} Repo slugs, deduplicated, in first-seen order
local function reached_repos(body: string): {string}
  local seen: {string: boolean} = {}
  local out: {string} = {}
  for _, slug in ipairs(github_urls(body)) do
    if not seen[slug] then
      seen[slug] = true
      out[#out + 1] = slug
    end
  end
  return out
end

--- The repositories a spec's `## Access` section names as read access
--- it needs, cheaply and loosely: a `github.com` URL there, or a bare
--- `owner/repo` mention — the section exists to be written once and
--- read, not parsed strictly, so a spurious extra entry costs nothing
--- (it can only make a real reference look MORE declared, never less).
--- @param body string The spec sidecar's markdown
--- @return {string: boolean} Declared repo slugs, lower-cased
local function declared_repos(body: string): {string: boolean}
  local text = sections(body)[ACCESS] or ""
  local out: {string: boolean} = {}
  for _, slug in ipairs(github_urls(text)) do
    out[slug] = true
  end
  for owner, name in text:gmatch("([%w%-%.]+)/([%w%-%._]+)") do
    out[(owner .. "/" .. (name:gsub("%.$", ""))):lower()] = true
  end
  return out
end

--- The revision of a spec sidecar: the git blob sha `spec.md` itself
--- carries in the item's tree, computed here without touching git —
--- the same `sha1("blob " .. #body .. "\0" .. body)` `git hash-object`
--- would give the identical bytes, so a revision recorded here always
--- matches what `_work.store` actually wrote. Two readings of the same
--- text give the same revision, and any edit gives a different one; a
--- body of "" — an item with no sidecar — hashes to a stable constant,
--- which is the right answer rather than a case to special-case: an
--- item that has never had a spec has not changed one.
--- @param body string The spec sidecar's markdown, "" when it has none
--- @return string The revision, 40 lowercase hex characters
local function revision(body: string): string
  return hash.digest_hex("sha1", ("blob %d\0%s"):format(#body, body))
end

--- The markdown document one `itemtree.Spec` renders to: `## Change`,
--- then `## Non-goals` when the walls are stated. A field that is ""
--- contributes no heading at all, so a spec with no prose renders to
--- "" — which is what every caller that still asks "does this item
--- have a spec" tests against.
---
--- This is a RENDERING, for the consumers that read a whole body: the
--- bar, the path extractors, full-text search, and `show --raw`'s own
--- output, which is the text an author edits and hands back to
--- `spec ID FILE`. `split` below is its inverse.
--- @param sp itemtree.Spec The two blobs
--- @return string The markdown document, "" when neither field carries prose
local function document(sp: itemtree.Spec): string
  local parts: {string} = {}
  local change = (sp.change or ""):gsub("\n+$", "")
  local non_goals = (sp.non_goals or ""):gsub("\n+$", "")
  if change ~= "" then
    parts[#parts + 1] = "## Change\n\n" .. change .. "\n"
  end
  if non_goals ~= "" then
    if #parts > 0 then
      parts[#parts + 1] = "\n"
    end
    parts[#parts + 1] = "## Non-goals\n\n" .. non_goals .. "\n"
  end
  return table.concat(parts)
end

--- The lines of one section, as the blob stores them: leading and
--- trailing blank lines dropped, a single trailing newline when
--- anything is left, "" when nothing is. So `split(document(sp))`
--- gives `sp` back for a canonical record, and `document(split(x))`
--- normalizes any conforming `x` to that canonical form.
--- @param lines {string} The section's raw lines, in order
--- @return string The blob text
local function section_blob(lines: {string}): string
  local first = 1
  local last = #lines
  while first <= last and not lines[first]:match("%S") do
    first = first + 1
  end
  while last >= first and not lines[last]:match("%S") do
    last = last - 1
  end
  if first > last then
    return ""
  end
  local out: {string} = {}
  for i = first, last do
    out[#out + 1] = lines[i] .. "\n"
  end
  return table.concat(out)
end

--- Where the fact a retired spec section used to carry now lives —
--- the second half of `split`'s refusal, one line per case. `access`
--- and `ready when` name the field that replaced them; everything else
--- was retrospective, and a measurement or a narrative is a log entry.
--- The two field refusals deliberately name NO verb: the flags that
--- declare them are their own change, and a refusal naming a flag this
--- build does not have is worse than one naming only the fact.
--- @param heading string The heading's own text, as written
--- @return string The refusal
local function retired_section(heading: string): string
  local lowered = heading:lower()
  if lowered == "access" then
    return "access is a declared field now, not a spec section"
  end
  if lowered == "ready when" then
    return "a precondition is a dependency, not a section"
  end
  return ("%s is not a spec section — a measurement or a narrative is a log "
    .. "entry: gitboard log ID --add FILE"):format(heading)
end

--- Split one markdown document into the two blobs the `spec/` subtree
--- holds — the inverse of `document` above, and the ONE text-to-record
--- seam every writer that holds a whole file goes through.
---
--- Its own scanner rather than `sections`, for two reasons that are
--- properties of `sections`, not of markdown: `sections` ends a
--- section at a thematic break, and neither scanner used to be
--- fence-aware. `sections` is the spec bar over every live sidecar on
--- the board, so tightening it is its own change measured against that
--- corpus; this reads only what this build writes, and is strict from
--- the start:
---
---   * fence-aware — a line inside a ``` fence is content, never a
---     heading, so a spec quoting `## Change` inside a pasted
---     command's output is ordinary prose;
---   * level-aware — a section opens at a heading whose lower-cased
---     text is `change` or `non-goals`, at whatever level the file
---     spells it, and runs until the next heading with no more `#`
---     than the opener, so a Change with `###` subsections keeps all
---     of it. A level-1 opener is the exception `sections` makes for
---     the same reason: a lone `#` is a document TITLE, so nothing
---     nests inside it and the next heading of any level closes it;
---   * thematic breaks are content — a `---` line is a table rule or
---     a separator, and ends nothing.
---
--- Anything else CARRYING CONTENT is refused rather than dropped: a
--- heading that opens a section of its own, is neither of the two, and
--- has a non-blank line under it, and non-blank text ahead of the
--- first heading. A hollow leftover heading loses no fact and is
--- dropped. Without the refusal the retired vocabulary simply
--- reappears in whichever blob happens to be open, which is the whole
--- point of there being no escape hatch.
--- @param body string One markdown file's text
--- @return itemtree.Spec | nil The two blobs
--- @return string The refusal, naming the offending heading
local function split(body: string): itemtree.Spec | nil, string
  local change: {string} = {}
  local non_goals: {string} = {}
  -- The open section's own buffer, nil ahead of the first heading and
  -- for a section this build does not keep — whose first non-blank
  -- line is the refusal, so `other` names which heading to cite.
  local current: {string} = nil
  local other = ""
  local level = 0
  local fenced = false
  for line in (body .. "\n"):gmatch("([^\n]*)\n") do
    local is_fence = line:match("^%s*```+") ~= nil
    local hashes, text = line:match("^(#+)%s+(.-)%s*$")
    if is_fence then
      fenced = not fenced
      if current ~= nil then
        current[#current + 1] = line
      end
    elseif not fenced and text ~= nil
    and (current == nil and other == "" or level == 1 or #hashes <= level) then
      local lowered = text:lower()
      current, other = nil, ""
      if lowered == "change" then
        current = change
      elseif lowered == "non-goals" then
        current = non_goals
      else
        other = text
      end
      level = #hashes
    elseif current ~= nil then
      current[#current + 1] = line
    elseif line:match("%S") then
      if other ~= "" then
        return nil, retired_section(other)
      end
      return nil, ("text before the first heading is not a spec section — a "
        .. "measurement or a narrative is a log entry: gitboard log ID "
        .. "--add FILE")
    end
  end
  return {change = section_blob(change), non_goals = section_blob(non_goals)}, ""
end

local record spec
  READY_SECTIONS: {string}
  document: function(sp: itemtree.Spec): string
  split: function(body: string): itemtree.Spec | nil, string
  sections: function(body: string): {string: string}
  ready_gaps: function(body: string): {string}
  reached_repos: function(body: string): {string}
  declared_repos: function(body: string): {string: boolean}
  revision: function(body: string): string
end

local M: spec = {
  READY_SECTIONS = READY_SECTIONS,
  document = document,
  split = split,
  sections = sections,
  ready_gaps = ready_gaps,
  reached_repos = reached_repos,
  declared_repos = declared_repos,
  revision = revision,
}

return M
