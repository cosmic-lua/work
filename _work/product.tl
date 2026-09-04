--- The one repository this board exists to move work on. Everything
--- that means "the repo the work is FOR" — an item's default `repo`
--- (`_work.item`), the scheduled workflows `_work.lanes` observes,
--- the repo `_work.intake`-style triage files issues against — names
--- this constant explicitly, never derives it from a checkout's own
--- `origin` remote.
---
--- That derivation is what `_work.gh`'s `slug` still does, correctly:
--- `origin` answers "where does THIS BOARD live and push to", a
--- different question with a different answer — this checkout's
--- `origin` is the board repository itself (`cosmic-lua/work`), not
--- the product repository named here. Before the board moved out of
--- cosmic's `board` branch into its own history, the two questions
--- happened to share one answer, which is what let `gh.slug(s, nil)`
--- stand in for both; they no longer do, so anything that meant the
--- product repo has to say so.
local record product
  REPO: string
  --- This board's own repository — where the machinery itself lands
  --- a PR, as opposed to `REPO`, where the work it tracks does.
  --- `_work.import`'s repo-default rule is the one place this is read:
  --- an imported item whose `base` names the board's old home
  --- (`"board"`, the branch it lived on before this repository
  --- existed) targets this repo's `main` instead.
  BOARD_REPO: string
end

local M: product = {
  REPO = "cosmic-lua/cosmic",
  BOARD_REPO = "cosmic-lua/work",
}

return M
