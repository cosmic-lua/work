--- Fuzz properties for `_work.itemtree`'s pure text/table parsers: the
--- `target` line (`format_target`/`parse_target`) and the `meta` blob
--- (`encode_meta`/`parse_meta`/`to_item`) — the exact text a git tree
--- blob carries for one item, and therefore exactly what a corrupted or
--- hand-edited commit hands back to a live read. Five properties:
---   parse_target is total over arbitrary bytes,
---   format_target/parse_target round-trip over github-shaped repo/base,
---   parse_meta is total over arbitrary bytes,
---   to_item is total over an adversarial meta table, order list, and edge lists, and
---   a validly-shaped item round-trips through encode_meta/parse_meta.
--- Every table-valued property still generates a string, length-prefixed
--- the way `_fuzz/url_fuzz_test.tl`'s query map does, so the driver's
--- replay/shrink machinery and its base64 failure report both apply.
--- env: FUZZ_SEED FUZZ_ITERS

local check = require("cosmic.check")
local driver = require("_fuzz.driver")
local item = require("_work.item")
local itemtree = require("_work.itemtree")
local ksuid = require("_work.ksuid")
local source = require("_fuzz.source")

--- Write one length-prefixed field: `<n>:<bytes>`.
--- @param out {string} Accumulator to append to
--- @param s string The field
local function put(out: {string}, s: string)
  out[#out + 1] = tostring(#s) .. ":" .. s
end

--- A cursor over a length-prefixed blob `put` wrote.
local record Cursor
  blob: string
  pos: integer
end

--- Read one field `put` wrote, advancing the cursor.
--- @param c Cursor The cursor
--- @return string | nil The field
--- @return string Error message, when malformed
local function take(c: Cursor): string | nil, string
  local colon = c.blob:find(":", c.pos, true)
  if not colon then
    return nil, "no length prefix at " .. tostring(c.pos)
  end
  local size = math.tointeger(tonumber(c.blob:sub(c.pos, colon - 1)))
  if not size then
    return nil, "bad length at " .. tostring(c.pos)
  end
  local value = c.blob:sub(colon + 1, colon + size)
  if #value ~= size then
    return nil, "short read at " .. tostring(c.pos)
  end
  c.pos = colon + 1 + size
  return value
end

--- Draw a run of characters from `alphabet`, the shape of a github
--- owner/name/branch label.
--- @param src source.Recorder The source to draw from
--- @param alphabet string The characters to draw from
--- @param max_len integer The longest run to produce
--- @return string The label
local function label(src: source.Recorder, alphabet: string, max_len: integer): string
  local out: {string} = {}
  for i = 1, src:int(1, max_len) do
    local pos = src:int(1, #alphabet)
    out[i] = alphabet:sub(pos, pos)
  end
  return table.concat(out)
end

local OWNER_CHARS < const > = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-."
local NAME_CHARS < const > = OWNER_CHARS .. "_"
local BRANCH_CHARS < const > = NAME_CHARS .. "/"

--- Draw a repo shaped exactly like `item.problems`' own regex expects
--- (`^[%w%-%.]+/[%w%-%._]+$`), or "" — never containing '@', the
--- `target` line's own separator.
--- @param src source.Recorder The source to draw from
--- @return string The repo, possibly ""
local function plausible_repo(src: source.Recorder): string
  if src:int(1, 5) == 1 then
    return ""
  end
  return label(src, OWNER_CHARS, 8) .. "/" .. label(src, NAME_CHARS, 8)
end

--- Draw a base branch name, or "".
--- @param src source.Recorder The source to draw from
--- @return string The base, possibly ""
local function plausible_base(src: source.Recorder): string
  if src:int(1, 3) == 1 then
    return ""
  end
  return label(src, BRANCH_CHARS, 8)
end

-- parse_target answers every byte string: repo, base and a problem
-- string, never throwing. A target with two or more '@' names its own
-- problem; anything else is silently accepted, per its own doc.
local function test_parse_target_totality()
  local ok, message = driver.run({
      name = "parse_target_totality",
      gen = function(src: source.Recorder): string
        return driver.bytes(src, 128)
      end,
      check = function(input: string): boolean, string
        local repo, base, problem = itemtree.parse_target(input)
        if type(repo) ~= "string" or type(base) ~= "string"
        or type(problem) ~= "string" then
          return false, "returned a non-string"
        end
        return true
      end,
    })
  check.truthy(ok, message)
end

-- format_target is documented as parse_target's inverse. Over repo/base
-- shaped exactly as item.problems requires (so neither ever embeds the
-- '@' separator), the round trip must hold with no reported problem.
local function test_target_round_trip()
  local ok, message = driver.run({
      name = "target_round_trip",
      gen = function(src: source.Recorder): string
        local out: {string} = {}
        put(out, plausible_repo(src))
        put(out, plausible_base(src))
        return table.concat(out)
      end,
      check = function(input: string): boolean, string
        local c: Cursor = {blob = input, pos = 1}
        local repo, rerr = take(c)
        local base, berr = take(c)
        if not repo or not base then
          return false, "generated input did not decode: "
          .. tostring(rerr or berr)
        end
        local target = itemtree.format_target(repo, base)
        local got_repo, got_base, problem = itemtree.parse_target(target)
        if problem ~= "" then
          return false, string.format(
            "round trip flagged a problem: repo=%q base=%q target=%q: %s",
            repo, base, target, problem)
        end
        if got_repo ~= repo or got_base ~= base then
          return false, string.format(
            "round trip changed the value: repo=%q base=%q target=%q got=%q/%q",
            repo, base, target, got_repo, got_base)
        end
        return true
      end,
    })
  check.truthy(ok, message)
end

-- parse_meta answers every byte string with a table, never throwing: a
-- line that does not match "key: value" is skipped, per its own doc.
local function test_parse_meta_totality()
  local ok, message = driver.run({
      name = "parse_meta_totality",
      gen = function(src: source.Recorder): string
        return driver.bytes(src, 256)
      end,
      check = function(input: string): boolean, string
        local meta = itemtree.parse_meta(input)
        if type(meta) ~= "table" then
          return false, "did not return a table"
        end
        return true
      end,
    })
  check.truthy(ok, message)
end

local META_KEYS < const >: {string} = {"title", "parent", "target", "key",
  "claim", "reviewer", "pr", "result", "verdict", "verdict_head",
  "verdict_spec", "resolution", "builders", "speccers"}

--- Draw an id: usually a fresh ksuid, sometimes deliberately not one
--- (empty, garbage) — to_item's edge lists carry raw strings from the
--- tree, and a hand-edited commit can name anything at all.
--- @param src source.Recorder The source to draw from
--- @return string The id
local function some_id(src: source.Recorder): string
  local kind = src:int(1, 4)
  if kind == 1 then
    return ""
  end
  if kind == 2 then
    return label(src, OWNER_CHARS, 10)
  end
  return ksuid.new()
end

-- to_item builds an Item from whatever a tree handed back, however
-- garbled: it must never throw, and it always returns an Item (content
-- problems land in .decode_problems, per its own doc) carrying the id
-- it was given.
local function test_to_item_totality()
  local ok, message = driver.run({
      name = "to_item_totality",
      gen = function(src: source.Recorder): string
        local out: {string} = {}
        for _, k in ipairs(META_KEYS) do
          if src:int(1, 2) == 1 then
            put(out, k)
            put(out, driver.bytes(src, 16))
          end
        end
        put(out, "") -- meta terminator: an empty key never matches a real one
        for _ = 1, src:int(0, 4) do
          put(out, "order")
          put(out, some_id(src))
        end
        for _ = 1, src:int(0, 4) do
          put(out, "beats")
          put(out, some_id(src))
        end
        for _ = 1, src:int(0, 4) do
          put(out, "blocked_by")
          put(out, some_id(src))
        end
        put(out, tostring(src:int(1, 2))) -- held
        return table.concat(out)
      end,
      check = function(input: string): boolean, string
        local c: Cursor = {blob = input, pos = 1}
        local meta: {string: string} = {}
        while true do
          local key = take(c)
          if key == nil or key == "" then
            break
          end
          local value = take(c)
          if value == nil then
            return false, "generated input did not decode (meta value)"
          end
          meta[key] = value
        end
        local order: {string} = {}
        local beats: {string} = {}
        local blocked_by: {string} = {}
        while true do
          local kind = take(c)
          if kind == nil then
            return false, "generated input did not decode (kind)"
          end
          if kind ~= "order" and kind ~= "beats" and kind ~= "blocked_by" then
            -- kind now actually holds the `held` flag, "1" or "2"
            local id = ksuid.new()
            local ok, it = pcall(itemtree.to_item, id, meta, kind == "2",
              order, beats, blocked_by, {}, {})
            if not ok then
              return false, "threw: " .. tostring(it)
            end
            if it == nil then
              return false, "returned nil"
            end
            if it.id ~= id then
              return false, "changed the id it was given"
            end
            return true
          end
          local id, ierr = take(c)
          if not id then
            return false, "generated input did not decode (id): " .. tostring(ierr)
          end
          if kind == "order" then
            order[#order + 1] = id
          elseif kind == "beats" then
            beats[#beats + 1] = id
          else
            blocked_by[#blocked_by + 1] = id
          end
        end
      end,
    })
  check.truthy(ok, message)
end

-- A validly-shaped item — the one every ordinary write produces —
-- round-trips through encode_meta/parse_meta/to_item with no content
-- problems and the same meta-carried fields back.
local function test_meta_round_trip()
  local ok, message = driver.run({
      name = "meta_round_trip",
      gen = function(src: source.Recorder): string
        local title = label(src, OWNER_CHARS .. "  ", 20):match("^%s*(.-)%s*$")
        if title == "" then
          title = "x"
        end
        local out: {string} = {}
        put(out, title)
        put(out, plausible_repo(src))
        put(out, plausible_base(src))
        put(out, tostring(src:int(0, 999)))
        return table.concat(out)
      end,
      check = function(input: string): boolean, string
        local c: Cursor = {blob = input, pos = 1}
        local title = take(c)
        local repo = take(c)
        local base = take(c)
        local pr_text = take(c)
        if not title or not repo or not base or not pr_text then
          return false, "generated input did not decode"
        end
        local it: item.Item = {
          id = ksuid.new(), title = title, parent = "", repo = repo,
          base = base, key = "", order = {}, beats = {}, blocked_by = {},
          block_reason = {}, claim = "", builders = {}, speccers = {},
          reviewer = "", pr = math.tointeger(tonumber(pr_text)) or 0,
          result = "", verdict = "", verdict_head = "", verdict_spec = "",
          resolution = "",
        }
        local bad = item.problems(it)
        if #bad > 0 then
          return true -- an unlucky draw (title punctuation, say); not this property's concern
        end
        local meta_text = itemtree.encode_meta(it)
        local meta = itemtree.parse_meta(meta_text)
        local round = itemtree.to_item(it.id, meta, false, {}, {}, {}, {}, {})
        if item.is_flagged(round) then
          return false, string.format("round trip flagged: %s",
            table.concat(round.decode_problems or {}, "; "))
        end
        if round.title ~= it.title then
          return false, string.format("title did not round-trip: %q -> %q",
            it.title, round.title)
        end
        if round.repo ~= it.repo then
          return false, string.format("repo did not round-trip: %q -> %q",
            it.repo, round.repo)
        end
        if round.base ~= it.base then
          return false, string.format("base did not round-trip: %q -> %q",
            it.base, round.base)
        end
        if round.pr ~= it.pr then
          return false, string.format("pr did not round-trip: %d -> %d",
            it.pr, round.pr)
        end
        return true
      end,
    })
  check.truthy(ok, message)
end
