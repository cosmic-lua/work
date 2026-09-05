--- The one freshness window every scheduled-observation cache shares:
--- how long a live read stays trusted before a caller is willing to
--- spend another GitHub round trip on it. `_work.lanes` (scheduled
--- workflow health) and `_work.ciobs` (a pull request's CI state) each
--- keep their own cache and their own env override, but both trust an
--- observation for the same span — one value that moves both rather
--- than two copies drifting apart.
local record freshness
  WINDOW_S: integer
end

local M: freshness = {
  WINDOW_S = 15 * 60,
}

return M
