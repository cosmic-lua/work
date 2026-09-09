--- The `done` verb: end an item, recording why — split out of
--- `_work.gitverbs` to keep that file under the repo's line cap. The
--- board- and outcome-specific gates (the board refused outright;
--- `--by CHILD` on a verified outcome) are `_work.gitdoneroot`; every
--- gate here is unchanged, since the board carries no claim, PR or
--- builders (`item.problems`) for any of them to fire on.
local doneroot = require("_work.gitdoneroot")
local commit_evidence = require("_work.commit_evidence")
local gate = require("_work.gitgate")
local item = require("_work.item")
local read = require("_work.read")
local repository_map = require("_work.repository_map")
local store = require("_work.store")

--- @param by string | nil The completed child verifying an outcome, "" off one
--- @param s store.Store The store
--- @param id string The item to end
--- @param reason string "completed" | "not-planned"
--- @param force boolean Force past an unmerged/unverdicted PR
--- @param why string Why --force was needed
--- @return integer Exit code
local function cmd_done(s: store.Store, id: string, reason: string,
    force: boolean, why: string, by?: string, landed?: string,
    repo_dir?: string, session?: string): integer
  local forced = gate.force_refusal(force, why)
  if forced then
    return gate.verdict_line("done", false, "REFUSED: " .. forced)
  end
  if reason ~= "completed" and reason ~= "not-planned" then
    return gate.verdict_line("done", false, ("unknown reason: %s"):format(reason))
  end
  -- `store.list` alone: same as `cmd_take`/`cmd_drop` in `_work.gitverbs`.
  local all, aerr = store.list(s)
  if all == nil then
    return gate.verdict_line("done", false, aerr)
  end
  local it = item.by_id(all)[id]
  if it == nil then
    return gate.verdict_line("done", false, ("no item %s"):format(id))
  end
  local c, cerr = store.read(s)
  if c == nil then
    return gate.verdict_line("done", false, cerr)
  end
  local by_id = by or ""
  local refusal, drerr = doneroot.done_refusal(c, all, it, reason, by_id)
  if drerr ~= "" then
    return gate.verdict_line("done", false, drerr)
  end
  if refusal then
    return gate.verdict_line("done", false, "REFUSED: " .. refusal)
  end
  -- An open PR is work mid-review: ending the item under it makes the
  -- diff vanish from the board while it still exists on GitHub. An
  -- unreviewed PR is dropped or judged first.
  if (it.pr or 0) ~= 0 and (it.verdict or "") ~= "accept" and not force then
    return gate.verdict_line("done", false,
      ("REFUSED: %s has PR #%d awaiting a verdict — done after an accept, "
        .. "or `drop` releases the handover"):format(id:sub(1, 8), it.pr))
  end
  -- A PR-less item that was ever worked is evidence mid-review the same
  -- way: `verdict` now judges it too (re-running the spec's recorded
  -- checks in place of a diff, per skills/work/SKILL.md), so ending it
  -- here with no accept would carry the same unreviewed claim of
  -- success the PR guard above exists to stop. This keys on `builders`
  -- — the append-only record of every session that ever held the claim
  -- — rather than the LIVE claim: `drop` clears `claim` without
  -- touching `builders`, so a live-claim check lets take -> drop -> done
  -- complete worked research silently, with no verdict and no --force.
  -- An item never claimed (no builders, ever) carries no such claim of
  -- success, so it is untouched. `--force --why` is the same repair —
  -- ending an item nothing will ever review (an obsolete slice, a
  -- duplicate) still goes through, named on the record.
  if (it.pr or 0) == 0 and #(it.builders or {}) > 0 and (it.verdict or "") ~= "accept"
  and not force then
    return gate.verdict_line("done", false,
      ("REFUSED: %s has no PR and no accept — an evidence-only item takes "
        .. "a verdict too; record one (`gitboard verdict`), or end it "
        .. "without review via --force --why"):format(id:sub(1, 8)))
  end
  -- Commit-only completion. The caller fetched the product repository and
  -- supplied the landed commit. Gitboard proves locally that the accepted
  -- commit is in its ancestry or that a bounded first-parent suffix carries
  -- the exact accepted content patch (squash/rebase).
  local handed = it.handover_head or ""
  if reason == "completed" and (it.verdict or "") == "accept"
  and handed ~= "" then
    if (it.verdict_head or "") ~= handed then
      return gate.verdict_line("done", false,
        "REFUSED: acceptance must name the current handover commit")
    end
    if (landed or "") == "" then
      if not force then
        return gate.verdict_line("done", false,
          "REFUSED: completed accepted work names its landed commit with --landed")
      end
    else
      local root, maperr = repository_map.resolve(s.root, it.repo or "",
        repo_dir or "")
      if root == nil then
        return gate.verdict_line("done", false, "REFUSED: " .. maperr)
      end
      local canonical, verr = commit_evidence.verify_landing(root,
        it.claim_base or "", it.verdict_head or "", landed or "")
      if canonical == nil then
        return gate.verdict_line("done", false, "REFUSED: " .. verr)
      end
      it.landed_head = canonical
    end
  elseif (landed or "") ~= "" then
    return gate.verdict_line("done", false,
      "REFUSED: --landed belongs to completed accepted work")
  end
  local role, rerr = read.role(c, it.id)
  if role == nil then
    return gate.verdict_line("done", false, rerr)
  end
  local from = "todo"
  if role ~= "work" then
    from = role
  else
    local st, sterr = read.state(c, it.id)
    if st == nil then
      return gate.verdict_line("done", false, sterr)
    end
    if st == "doing" then
      local sub, suberr = read.substate(c, it.id)
      if sub == nil then
        return gate.verdict_line("done", false, suberr)
      end
      from = sub
    end
  end
  it.resolution = reason
  -- CHILD rides the commit subject and the verdict line: the log names
  -- the evidence a verified outcome stands on.
  local by_note = ""
  if by_id ~= "" then
    by_note = (" by %s"):format(by_id:sub(1, 8))
  end
  local ok, err = gate.commit_and_publish(s, it, nil,
    ("done %s %s%s (from %s)%s"):format(id:sub(1, 8), reason, by_note, from,
      gate.forced_suffix(force, why)), "done", nil, session, false, force, why)
  if not ok then
    return gate.verdict_line("done", false, err)
  end
  if store.is_noop(err) then
    return gate.verdict_line("done", true, err)
  end
  -- A parent whose last open child just ended is workable again by
  -- derivation — nothing to write, but worth saying: verifying the
  -- outcome its children were supposed to deliver is the next thing
  -- anyone does with it.
  local returned = ""
  local parent = item.by_id(all)[it.parent or ""]
  if parent ~= nil and item.is_open(parent) then
    local siblings = false
    for _, other in ipairs(all) do
      if other.parent == parent.id and other.id ~= it.id
      and item.is_open(other) then
        siblings = true
        break
      end
    end
    if not siblings then
      returned = (" — %s was %s's last open child: verify its outcome "
        .. "holds, then end it"):format(id:sub(1, 8), parent.id:sub(1, 8))
    end
  end
  return gate.verdict_line("done", true,
    ("%s %s%s (%s)%s"):format(id:sub(1, 8), reason, by_note, from, returned))
end

local record gitdone
  cmd_done: function(s: store.Store, id: string, reason: string,
  force: boolean, why: string, by?: string, landed?: string,
  repo_dir?: string, session?: string): integer
end

local M: gitdone = {
  cmd_done = cmd_done,
}

return M
