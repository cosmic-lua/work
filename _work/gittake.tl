--- The takes `take` reaches by derivation rather than by a verb of
--- their own — an item's facts, never a declaration, say which one a
--- take is (`_work.gitverbs.cmd_take` is the dispatch):
---
---   take_review  an item awaiting a verdict, taken by a session that
---                is not its builder: the review claim, the lock
---                pushed BEFORE the reading starts
---   take_result  `take ID --result`, the claim holder handing a
---                research slice over for that verdict — the mirror
---                of `take ID --pr N` for work whose deliverable is
---                board state, not a diff
---   take_open    `take ID --open`, the claim holder asking for the
---                caller-side PR operation gitboard no longer performs
---
--- All three are motion on work already in flight and ask neither of
--- the pull's gates. Split from `_work.gitverbs`, which sits against
--- the file cap.
local fs = require("cosmic.fs")
local commit_evidence = require("_work.commit_evidence")
local gate = require("_work.gitgate")
local health = require("_work.health")
local item = require("_work.item")
local gitreadspec = require("_work.gitreadspec")
local repository_map = require("_work.repository_map")
local store = require("_work.store")

--- Record a commit-only handover after verifying the product commit locally.
--- The optional URL is navigation metadata and participates in no gate.
local function take_handover(s: store.Store, it: item.Item, session: string,
    head: string, external_url: string, repo_dir: string): integer
  local id8 = it.id:sub(1, 8)
  if (it.claim or "") ~= session then
    return gate.verdict_line("take", false,
      ("REFUSED: %s's handover belongs to its claim holder"):format(id8))
  end
  local claim_base = it.claim_base or ""
  if claim_base == "" then
    return gate.verdict_line("take", false,
      ("REFUSED: %s's claim has no product base commit"):format(id8))
  end
  local root, rerr = repository_map.resolve(s.root, it.repo or "", repo_dir)
  if root == nil then
    return gate.verdict_line("take", false, "REFUSED: " .. rerr)
  end
  local lineage, verr = commit_evidence.verify_lineage(root, claim_base, head)
  if lineage == nil then
    return gate.verdict_line("take", false, "REFUSED: " .. verr)
  end
  local canonical = lineage.head
  local accepted = it.verdict == "accept" and it.verdict_head == canonical
  if external_url ~= "" and not external_url:match("^https?://%S+$") then
    return gate.verdict_line("take", false,
      "REFUSED: --url must be one http(s) URL")
  end
  if (it.handover_head or "") == canonical
  and (external_url == "" or (it.external_url or "") == external_url)
  and (it.verdict or "") ~= "request changes"
  and (it.verdict ~= "accept" or accepted) then
    return gate.verdict_line("take", true,
      ("%s already hands over %s"):format(id8, canonical:sub(1, 12)))
  end
  it.handover_head = canonical
  local recorded, ierr = item.record_involvement(it.builders, session)
  if not recorded then
    return gate.verdict_line("take", false, "REFUSED: " .. ierr)
  end
  if external_url ~= "" then it.external_url = external_url end
  it.pr, it.result = 0, ""
  -- Acceptance belongs to one commit. Prior verdicts remain in item history;
  -- a different handover needs a fresh verdict, while URL-only edits do not.
  if not accepted then
    it.verdict, it.verdict_head = "", ""
  end
  local bad = item.problems(it)
  if #bad > 0 then
    return gate.verdict_line("take", false, "REFUSED: " .. table.concat(bad, "; "))
  end
  local ok, err = gate.commit_and_publish(s, it, nil,
    ("take %s by %s head:%s"):format(id8, session, canonical:sub(1, 12)),
    "take", nil, session)
  if not ok then return gate.verdict_line("take", false, err) end
  -- A same-head metadata-only edit (a URL attached, say) leaves the standing
  -- acceptance in force above: say so, rather than the generic "awaiting
  -- review" this same write path prints for every other handover, which
  -- would contradict the exact-head acceptance `show` and a repeat verdict
  -- both still honor.
  if accepted then
    return gate.verdict_line("take", true,
      ("%s is accepted (same head; external URL updated)"):format(id8))
  end
  return gate.verdict_line("take", true,
    ("%s hands over %s — awaiting review"):format(id8, canonical:sub(1, 12)))
end

--- The review claim: the lock pushed BEFORE the
--- reading starts, so two sessions never verify one diff. Reached by
--- derivation, not by a verb of its own — an item awaiting a verdict,
--- taken by a session that is not its builder, can only mean the
--- review. The claim is a lease (`health`'s review horizon — short,
--- because a review's dwell is minutes) and mutual exclusion only: a
--- verdict from any session stands and consumes it.
--- @param s store.Store The store
--- @param it item.Item The item whose review is claimed
--- @param session string The reviewing session
--- @param force boolean Take over a LIVE foreign review claim
--- @param why string Why --force was needed
--- @return integer Exit code
local function take_review(s: store.Store, it: item.Item, session: string,
    force: boolean, why: string): integer
  -- The distance guard binds here with no --force escape: a fresh
  -- context cannot be forced into existing, so a session that already
  -- built or specced this item never claims its review, live or stale.
  local distance = gate.distance_refusal(it, session)
  if distance then
    return gate.verdict_line("take", false, distance)
  end
  local id8 = it.id:sub(1, 8)
  if (it.reviewer or "") == session then
    return gate.verdict_line("take", true,
      ("%s's review is already yours"):format(id8))
  end
  -- A standing foreign claim splits on the lease: a live one is a
  -- reviewer mid read-verify-verdict, taken over only on the record;
  -- a stale one is a session that stopped moving the board, and the
  -- diff is anyone's again — the takeover is noted, never gated.
  local taken = ""
  if (it.reviewer or "") ~= "" and not force then
    local ages, agerr = gate.stale_ages(s)
    if ages == nil then
      return gate.verdict_line("take", false, agerr)
    end
    if not health.is_review_stale(it, ages.review) then
      return gate.verdict_line("take", false,
        ("REFUSED: %s is under review by %s — take over a live review "
          .. "with --force --why"):format(id8, it.reviewer))
    end
  end
  if (it.reviewer or "") ~= "" then
    taken = (" (taken over from %s)"):format(it.reviewer)
  end
  it.reviewer = session
  local ok, err = gate.commit_and_publish(s, it, nil,
    ("review %s claimed by %s%s"):format(id8, session,
      gate.forced_suffix(force, why)), "take", nil, session)
  if not ok then
    return gate.verdict_line("take", false, err)
  end
  return gate.verdict_line("take", true,
    ("%s's review is yours%s — verdict when done consumes the claim")
    :format(id8, taken))
end

--- The research handover: what `take --pr N` is for a diff, for an
--- item whose deliverable is the board — the spec as it stands once
--- the recommendation is applied (`spec`, then `new`/`attach`/`block`
--- per capture). Nothing on the item's fields could otherwise tell
--- "applied, awaiting a verdict" from "builder mid-flight": both are
--- claimed, PR-less, with builders on record. So the handover is
--- declared, and what it records is the BOARD COMMIT the applied
--- recommendation sits on — the item ref's tip as it stood when the
--- handover was made, which is the `spec`/`new`/`attach` commits the
--- researcher just landed. The handover commit is that commit's child,
--- so `git log <result>..<tip>` reads the handover itself; a commit
--- cannot carry its own sha in its own tree, which is why a
--- single-commit handover records the parent and not itself.
---
--- Only the live claim holder hands over — a handover asserts the
--- holder's own work is done, so there is no takeover here and no
--- gate to force — and never over a PR: an item's deliverable is a
--- diff or board state, never both (`item.problems` holds the same
--- rule on every write). The verdict moves exactly as `--pr` moves
--- it: a handover clears a `request changes` (the rework answered, a
--- new thing to judge) whether or not the spec moved — the same spec
--- handed over again is a no-op only while no send-back stands — and
--- an accept is never touched by a take: it is landed, and `verdict`
--- refuses to re-judge it.
--- @param s store.Store The store
--- @param it item.Item The item handed over
--- @param session string The handing-over session
--- @param pr integer The `--pr` given alongside, 0 for none
--- @return integer Exit code
local function take_result(s: store.Store, it: item.Item, session: string,
    pr: integer): integer
  local id8 = it.id:sub(1, 8)
  if (pr or 0) ~= 0 then
    return gate.verdict_line("take", false,
      "REFUSED: --pr and --result together — a deliverable is a diff or "
      .. "board state, never both")
  end
  if (it.pr or 0) ~= 0 then
    return gate.verdict_line("take", false,
      ("REFUSED: %s already carries PR #%d — its deliverable is that diff; "
        .. "a research handover records none"):format(id8, it.pr))
  end
  if (it.claim or "") ~= session then
    local holder = "unclaimed"
    if (it.claim or "") ~= "" then
      holder = ("claimed by %s"):format(it.claim)
    end
    return gate.verdict_line("take", false,
      ("REFUSED: %s is %s — the handover is the claim holder's; take it "
        .. "first"):format(id8, holder))
  end
  local body = store.read_spec(s, it.id)
  if body.change == "" and body.non_goals == "" then
    return gate.verdict_line("take", false,
      ("REFUSED: %s has no spec — a research handover hands the "
        .. "spec over, and there is none"):format(id8))
  end
  -- The tip `store.list` hydrated for this item: the commit the applied
  -- recommendation sits on. Refuse rather than record an empty sha —
  -- "" in `result` reads as "no handover recorded".
  local tip = s.leased_sha[it.id] or ""
  if tip == "" then
    return gate.verdict_line("take", false,
      ("REFUSED: %s has no observed board commit to hand over — read the "
        .. "board first"):format(id8))
  end
  local verdict = it.verdict or ""
  local standing = "awaiting review"
  if verdict ~= "" then
    standing = ("its %s stands"):format(verdict)
  end
  -- The predicate the recorded digest used to express — has the spec
  -- moved since the recorded handover — computed from git objects
  -- instead of a hash: tip-equality cannot express it, because after
  -- the first handover the tip IS the handover commit and never equals
  -- the recorded parent again. A legacy 40-hex digest resolves to no
  -- object, compares unequal, and is re-typed by this very handover.
  local recorded = gitreadspec.read_spec(s.root, {it.result or ""})
  if recorded.change == body.change and recorded.non_goals == body.non_goals
  and (it.result or "") ~= "" and verdict ~= "request changes" then
    return gate.verdict_line("take", true,
      ("%s already records this spec's handover — %s"):format(id8, standing))
  end
  local digest = tip
  it.result = digest
  if verdict == "request changes" then
    it.verdict = ""
    standing = "awaiting review"
  end
  local ok, err = gate.commit_and_publish(s, it, nil,
    ("take %s by %s result:%s"):format(id8, session, digest:sub(1, 7)),
    "take", nil, session)
  if not ok then
    return gate.verdict_line("take", false, err)
  end
  return gate.verdict_line("take", true,
    ("%s is yours result:%s — %s"):format(id8, digest:sub(1, 7), standing))
end

--- The PR body `take --open` sends: `Board: <full id>`, so the board
--- can join the opened PR back to the item, then a blank line and the
--- contents of `--body FILE` when one was given. Pure — no git, no
--- GitHub — so the shape is proven directly rather than only through
--- the network calls `take_open` wraps around it.
--- @param id string The item's full id
--- @param body_file string The `--body` file, "" for none
--- @return string | nil The body
--- @return string Error message
local function open_body(id: string, body_file: string): string | nil, string
  local board_line = ("Board: %s"):format(id)
  if body_file == "" then
    return board_line, ""
  end
  local extra, ferr = fs.read(body_file)
  if extra == nil then
    return nil, ("cannot read --body %s: %s"):format(body_file, ferr)
  end
  return board_line .. "\n\n" .. extra, ""
end

--- One-release compatibility surface for the removed `take --open` flow.
--- Gitboard does not render provider-specific commands: the caller owns the
--- authenticated push/open interaction, then records only its local product
--- commit (and optionally a navigation URL) through `take --head`.
--- @param s store.Store The store
--- @param it item.Item The item handed over
--- @param session string The handing-over session
--- @param pr integer The `--pr` given alongside, 0 for none
--- @param body_file string A file whose contents extend the PR body, "" for none
--- @return integer Exit code
local function take_open(_s: store.Store, _it: item.Item, _session: string,
    _pr: integer, _body_file: string): integer
  return gate.verdict_line("take", false,
    "REFUSED: legacy --open is disabled — push and open through the caller's "
    .. "authenticated tooling, then run `gitboard take ID --head SHA "
    .. "[--url URL]`")
end

local record gittake
  take_handover: function(s: store.Store, it: item.Item, session: string,
  head: string, external_url: string, repo_dir: string): integer
  take_review: function(s: store.Store, it: item.Item, session: string,
  force: boolean, why: string): integer
  take_result: function(s: store.Store, it: item.Item, session: string,
  pr: integer): integer
  take_open: function(s: store.Store, it: item.Item, session: string,
  pr: integer, body_file: string): integer
  --- Exported for tests only: the pure body construction `take_open`
  --- wraps around, proven directly rather than only through a stub
  --- standing in for the whole write.
  open_body: function(id: string, body_file: string): string | nil, string
end

local M: gittake = {
  take_handover = take_handover,
  take_review = take_review,
  take_open = take_open,
  open_body = open_body,
  take_result = take_result,
}

return M
