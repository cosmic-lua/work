--- The spec bar's grammar over the two blobs an item's `spec/`
--- subtree holds (`_work.itemtree`'s `Spec`): whether the Change says
--- anything at all, and whether a sweep-shaped Change pastes its own
--- dry-run evidence. Also the read-access half of the bar's input:
--- the repositories a spec's own text REACHES (a `github.com` URL,
--- wherever it sits), which `_work.gitready.undeclared_repos` checks
--- against the item's declared `access` field, so a claim or a review
--- that cannot reach one bounces at the bar instead of after a pull.
---
--- There is no Acceptance section, because acceptance is not
--- per-item: the CI gate passing is the one definition of done every
--- item shares, and proof specific to a change rides the DIFF as a
--- test or ratchet the gate runs — a gate outlives the sidecar that
--- asked for it. The bar checks only what a machine can check
--- honestly: whether the Change decides enough is the puller's
--- judgment (a wrong call comes back as a question the item gets
--- blocked on, or as a release),
--- and the Non-goals blob rides along unjudged. Whether a declared
--- repository is actually reachable is the same kind of judgment —
--- `_work.gitready` only checks that the requirement is STATED.
---
--- `document` and `split` are the two directions between the blobs
--- and the one markdown file an author edits: the bar reads the
--- record, never the rendering, so there is exactly one scanner
--- (`segments`, under `split`) and it runs only on a write.
local itemtree = require("_work.itemtree")

--- The two blobs an item with no prose at all reads as — what a
--- caller with no record to hand passes for one.
local NO_PROSE < const >: itemtree.Spec = {change = "", non_goals = ""}

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

--- The `.tl` paths a Change blob names in backticks — a caller
--- declaring `--touches` by hand types the same backticked form, so
--- `new` reads it back the same way when no `--touches` was typed. A
--- span holding whitespace is a sentence or a command, not one path,
--- and is skipped, which is also why a compound `touches: a.tl b.tl`
--- rendering never round-trips back into a derived list.
--- @param change string The Change blob's text
--- @return {string} `.tl` paths, once each, in first-seen order
local function touches_from_change(change: string): {string}
  local seen: {string: boolean} = {}
  local out: {string} = {}
  for _, span in ipairs(code_spans(change)) do
    if span:match("%.tl$") ~= nil and span:match("%s") == nil
    and not seen[span] then
      seen[span] = true
      out[#out + 1] = span
    end
  end
  return out
end

--- The gap a sweep-shaped Change leaves when its spec pastes no
--- dry-run evidence: a Change naming `--apply` or `--fix` needs a
--- fenced `rewrite:` or `applied` line somewhere in either blob — the
--- command's own dry-run output (the `applied`/`refused` line, or the
--- refusal), not only the `--find` count that named its sites. A
--- spec whose sweep command was never run at spec time is the wrong
--- turn this exists to catch. The flag is read from the Change blob
--- alone; the paste may sit in either.
--- @param sp itemtree.Spec The two blobs
--- @return {string} Zero or one gap
local function sweep_gaps(sp: itemtree.Spec): {string}
  local change = sp.change or ""
  if not (change:find("%-%-apply%f[%A]") or change:find("%-%-fix%f[%A]")) then
    return {}
  end
  for _, blob in ipairs({change, sp.non_goals or ""}) do
    for _, span in ipairs(code_spans(blob)) do
      if span:find("rewrite:", 1, true) or span:find("applied", 1, true) then
        return {}
      end
    end
  end
  return {"Change names a sweep (--apply/--fix) with no pasted dry-run "
    .. "output — paste the command's own `rewrite:`/`applied` (or "
    .. "refusal) line, not only the --find count"}
end

--- Spec-bar lint: the gaps that keep a record from being buildable,
--- each as one readable line. The Change blob counts as filled only
--- when it carries at least one non-blank line, so a pasted template
--- with a hollow Change still fails. No heading is scanned: the blob
--- IS the section.
--- @param sp itemtree.Spec | nil The two blobs; nil reads as no prose
--- @return {string} Gap descriptions, possibly empty
local function ready_gaps(sp: itemtree.Spec | nil): {string}
  local prose = sp or NO_PROSE
  local gaps: {string} = {}
  if not (prose.change or ""):match("%S") then
    gaps[#gaps + 1] = "Change is missing or empty"
  end
  for _, gap in ipairs(sweep_gaps(prose)) do
    gaps[#gaps + 1] = gap
  end
  return gaps
end

--- The `owner/repo` pairs a `github.com` URL in `text` names —
--- `https://github.com/owner/repo`, a bare `github.com/owner/repo`,
--- or the SSH `git@github.com:owner/repo` — normalized to lowercase
--- with a trailing `.git` or sentence-ending `.` stripped. The one
--- signal `reached_repos` reads: a URL is
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
--- `github.com` URL sits in it — a command in the Change, a wall in
--- the Non-goals. This is "reaches", not "needs": the item's own
--- `repo` and any self-mention are not filtered out here, because
--- that judgment needs the item — see `_work.gitready.undeclared_repos`.
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

--- The markdown document one `itemtree.Spec` renders to: `## Change`,
--- then `## Non-goals` when the walls are stated. A field that is ""
--- contributes no heading at all, so a spec with no prose renders to
--- "" — which is what every caller that still asks "does this item
--- have a spec" tests against.
---
--- This is a RENDERING, for the consumers that read a whole body: the
--- reach check, full-text search, and `show --raw`'s own output,
--- which is the text an author edits and hands back to `spec ID
--- FILE`. `split` below is its inverse.
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
--- and `ready when` name the field that replaced them AND the verb that
--- declares it, so a refusal is also the repair; everything else was
--- retrospective, and a measurement or a narrative is a log entry.
--- @param heading string The heading's own text, as written
--- @return string The refusal
local function retired_section(heading: string): string
  local lowered = heading:lower()
  if lowered == "access" then
    return "access is a declared field now, not a spec section: "
    .. "gitboard set ID --access OWNER/NAME"
  end
  if lowered == "ready when" then
    return "a precondition is a dependency, not a section: "
    .. "gitboard depend ID ON ID"
  end
  return ("%s is not a spec section — a measurement or a narrative is a log "
    .. "entry: gitboard log ID --add FILE"):format(heading)
end

--- One section of a markdown document as `segments` reads it: the
--- heading's own text as written, the heading's level, and the lines
--- under it as one blob (`section_blob`'s shape — outer blank lines
--- dropped, one trailing newline, "" when hollow). Level 0 is the one
--- segment with no heading: whatever non-blank text sits ahead of the
--- first heading, present only when there is any.
local record Segment
  level: integer
  heading: string
  text: string
end

--- Every section of one markdown document, in source order — the one
--- scanner `split` below stands on, and the only one in the tree:
---
---   * fence-aware — a line inside a ``` fence is content, never a
---     heading, so a spec quoting `## Change` inside a pasted
---     command's output is ordinary prose;
---   * level-aware — a section opens at any heading and runs until
---     the next heading with no more `#` than the opener, so a Change
---     with `###` subsections keeps all of it. A level-1 opener is the
---     exception: a lone `#` is a document TITLE, so nothing nests
---     inside it and the next heading of any level closes it;
---   * thematic breaks are content — a `---` line is a table rule or
---     a separator, and ends nothing.
--- @param body string One markdown file's text
--- @return {Segment} Its sections, in source order
local function segments(body: string): {Segment}
  local out: {Segment} = {}
  local lines: {string} = {}
  local level = 0
  local heading = ""
  local fenced = false
  local function flush()
    local text = section_blob(lines)
    if level > 0 or text ~= "" then
      out[#out + 1] = {level = level, heading = heading, text = text}
    end
    lines = {}
  end
  for line in (body .. "\n"):gmatch("([^\n]*)\n") do
    local is_fence = line:match("^%s*```+") ~= nil
    local hashes, text = line:match("^(#+)%s+(.-)%s*$")
    if is_fence then
      fenced = not fenced
      lines[#lines + 1] = line
    elseif not fenced and text ~= nil
    and (level <= 1 or #hashes <= level) then
      flush()
      level, heading = #hashes, text
    else
      lines[#lines + 1] = line
    end
  end
  flush()
  return out
end

--- Split one markdown document into the two blobs the `spec/` subtree
--- holds — the inverse of `document` above, and the ONE text-to-record
--- seam every writer that holds a whole file goes through. Built on
--- `segments`: a section opens at a heading whose lower-cased text is
--- `change` or `non-goals`, at whatever level the file spells it.
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
  for _, seg in ipairs(segments(body)) do
    local lowered = seg.heading:lower()
    if seg.level == 0 then
      return nil, ("text before the first heading is not a spec section — a "
        .. "measurement or a narrative is a log entry: gitboard log ID "
        .. "--add FILE")
    elseif lowered == "change" then
      change[#change + 1] = seg.text
    elseif lowered == "non-goals" then
      non_goals[#non_goals + 1] = seg.text
    elseif seg.text ~= "" then
      return nil, retired_section(seg.heading)
    end
  end
  return {change = table.concat(change), non_goals = table.concat(non_goals)}, ""
end

local record spec
  document: function(sp: itemtree.Spec): string
  split: function(body: string): itemtree.Spec | nil, string
  ready_gaps: function(sp: itemtree.Spec | nil): {string}
  reached_repos: function(body: string): {string}
  touches_from_change: function(change: string): {string}
end

local M: spec = {
  document = document,
  split = split,
  ready_gaps = ready_gaps,
  reached_repos = reached_repos,
  touches_from_change = touches_from_change,
}

return M
