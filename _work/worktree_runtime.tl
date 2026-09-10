--- Target-pinned runtime snapshots; process success is not artifact attestation.
local child = require("cosmic.child")
local fd = require("cosmic.fd")
local fs = require("cosmic.fs")
local hash = require("cosmic.hash")
local rand = require("cosmic.rand")
local profile = require("_work.repoprofile")

local record Pin
  text: string
  url: string
  digest: string
end
local record Runtime
  path: string
  prefix: {string}
  pin: Pin
end
local LIMIT < const > = 268435456
local PROBE < const > = 'io.write("gitboard-runtime-probe-v1\\n")'

local function git_failure(r: child.Result | nil, err: string): string
  if r == nil then return "could not run git: " .. err end
  return ("git failed (signal=%s, exit=%s): %s"):format(tostring(r.signal), tostring(r.code), r.stderr)
end

--- Read a bounded snapshot from one regular, non-symlink descriptor.
local function bytes(path: string, limit: integer): string | nil, string
  local h, err = fd.open(path, fd.O_RDONLY | fd.O_NOFOLLOW | fd.O_NONBLOCK)
  if h == nil then return nil, err end
  local st, serr = fs.stat_fd(h:fd())
  if st == nil or not st:is_file() or st:size() > limit then
    local _ok, _err = h:close()
    return nil, serr ~= "" and serr or "not a bounded regular file"
  end
  local parts: {string} = {}
  local size = 0
  while size <= limit do
    local part, rerr = h:read(math.min(65536, limit + 1 - size))
    if part == nil then
      local closed, cerr = h:close()
      if rerr ~= nil and rerr ~= "" then return nil, rerr end
      if not closed then return nil, cerr end
      return table.concat(parts), ""
    end
    size = size + #part
    parts[#parts + 1] = part
  end
  local _ok, _err = h:close()
  return nil, "file exceeds size limit"
end

local function parse(text: string): Pin | nil, string
  if #text > 16384 or text:find("%z") or text:sub(-1) == "\r" then return nil, "invalid pin size or physical bytes" end
  local values: {string: string} = {}
  for raw in (text .. "\n"):gmatch("([^\n]*)\n") do
    local line = raw:gsub("\r$", "")
    if not line:match("^[ \t]*$") and not line:match("^[ \t]*#") then
      local key, value = line:match("^([a-z0-9]+)[ \t]*=[ \t]*(.-)[ \t]*$")
      if key == nil or (key ~= "url" and key ~= "sha256") or values[key] ~= nil
      or value == nil or value == "" then return nil, "invalid or duplicate pin assignment" end
      values[key] = value
    end
    if line:find("\r", 1, true) or line:match("\\[ \t]*$") then
      return nil, "invalid pin physical line"
    end
  end
  local url, digest = values.url or "", values.sha256 or ""
  local authority = url:match("^https://([^/?#]+)")
  if authority == nil or authority:find("@", 1, true) or url:find("[%z\1-\32\127]")
  or url:find("#", 1, true) or url:find("\\", 1, true) then return nil, "invalid HTTPS pin URL" end
  if #digest ~= 64 or not digest:match("^[0-9a-f]+$") then return nil, "invalid pin sha256" end
  return {text = text, url = url, digest = digest}, ""
end

--- A missing committed pin is legacy only when no working pin is present.
--- @return Pin | nil Parsed target pin, nil for absent or refused
--- @return string Refusal, empty for absent
local function inspect(path: string, commit: string): Pin | nil, string
  local r, err = child.run({"git", "ls-tree", "-z", commit, "--", "bin/cosmic.pin"}, {cwd = path})
  if r == nil or not r.ok then return nil, git_failure(r, err) end
  if r.stdout == "" then
    if fs.stat_link(fs.join(path, "bin/cosmic.pin")) ~= nil then return nil, "pin is not tracked at target commit" end
    return nil, ""
  end
  local mode, sha = r.stdout:match("^(%d+) blob ([0-9a-f]+)\tbin/cosmic%.pin%z$")
  if mode ~= "100644" and mode ~= "100755" then return nil, "target pin is not a regular Git blob" end
  local size, sizeerr = child.run({"git", "cat-file", "-s", sha}, {cwd = path})
  if size == nil or not size.ok then return nil, git_failure(size, sizeerr) end
  local count = tonumber(size.stdout)
  if count == nil or count > 16384 then return nil, "invalid committed pin size" end
  local blob, berr = child.run({"git", "cat-file", "blob", sha}, {cwd = path})
  if blob == nil or not blob.ok then return nil, git_failure(blob, berr) end
  local current, cerr = bytes(fs.join(path, "bin/cosmic.pin"), 16384)
  if current == nil then return nil, "cannot read working pin: " .. cerr end
  if current ~= blob.stdout then return nil, "working pin differs from target commit" end
  return parse(current)
end

local function verified(path: string, digest: string): string | nil, string
  local text, err = bytes(path, LIMIT)
  if text == nil then return nil, err end
  if hash.sha256_hex(text) ~= digest then return nil, "sha256 mismatch" end
  return text, ""
end

local function output_refusal(root: string, path: string, directory: boolean): string
  local cursor = directory and path or fs.dirname(path)
  while cursor ~= root do
    if cursor == "/" or cursor == "." then return "output escapes checkout" end
    local st = fs.stat_link(cursor)
    if st ~= nil and not st:is_dir() then return "unsafe output ancestor: " .. cursor end
    cursor = fs.dirname(cursor)
  end
  local tracked, err = child.run({"git", "ls-files", "-z", "--", path}, {cwd = root})
  if tracked == nil or not tracked.ok then return git_failure(tracked, err) end
  if tracked.stdout ~= "" then return "tracked preparation output: " .. path end
  local ignored, ierr = child.run({"git", "check-ignore", "-q", "--",
      path .. (directory and "/" or "")}, {cwd = root})
  if ignored == nil or not ignored.ok then return "non-ignored preparation output: " .. path .. ": " .. (ierr or "") end
  return ""
end

local function directory(root: string, path: string): string
  local err = output_refusal(root, path, true)
  if err ~= "" then return err end
  if fs.is_dir(path) then return "" end
  local ok, merr = fs.make_dir(path, fs.octal("700"))
  return ok and "" or merr
end

local function write_new(root: string, path: string, text: string): string
  local err = output_refusal(root, path, false)
  if err ~= "" then return err end
  local h, herr = fd.open(path, fd.O_WRONLY | fd.O_CREAT | fd.O_EXCL | fd.O_NOFOLLOW, fs.octal("700"))
  if h == nil then return herr end
  local offset = 1
  while offset <= #text do
    local count, werr = h:write(text:sub(offset))
    if count == nil or count == 0 then
      local _ok, _err = h:close()
      return werr or "short write"
    end
    offset = offset + count
  end
  local ok, cerr = h:close()
  return ok and "" or cerr
end

local function rejection(path: string, err: string)
  print(("runtime rejected %q: %s"):format(path, err))
end

local function publish(root: string, pin: Pin, text: string): string
  local dir = fs.join(root, "o/bootstrap")
  local derr = directory(root, dir)
  if derr ~= "" then return derr end
  local destination = fs.join(dir, "cosmic.ape")
  local invalid = output_refusal(root, destination, false)
  if invalid ~= "" then return invalid end
  if fs.is_present(destination) then
    local winner, err = verified(destination, pin.digest)
    if winner == nil then rejection(destination, err) end
    return ""
  end
  local temporary = fs.join(dir, ".gitboard-" .. rand.token())
  local err = write_new(root, temporary, text)
  if err ~= "" then return err end
  local staged, serr = verified(temporary, pin.digest)
  local linked, lerr = false, serr
  if staged ~= nil then linked, lerr = fs.link(temporary, destination) end
  local removed, rerr = fs.remove(temporary)
  if not removed then return "publication temporary cleanup failed: " .. rerr end
  if staged == nil then return serr end
  if not linked then
    if not lerr:find("EEXIST", 1, true) then return lerr end
    local winner, werr = verified(destination, pin.digest)
    if winner == nil then rejection(destination, werr) end
  end
  return ""
end

--- The summary line(s) `--make` itself prints inside a step's captured
--- output: `verb: PASS (...)`/`verb: FAIL (...)`, the exact shape
--- `_tool.records.format_verdict` writes (`fetch: PASS (N pins)`,
--- `build: PASS (N files, 1 binary)`) — everything else, a `compile`/
--- `compile-batch` line per source file or `unpack`/`fetch`/`patch`
--- per pin, is dropped.
--- @param text string A step's captured stdout
--- @return {string} The summary lines, in the order they appeared
local function summary_of(text: string): {string}
  local out: {string} = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^%a+: PASS") ~= nil or line:match("^%a+: FAIL") ~= nil then
      out[#out + 1] = line
    end
  end
  return out
end

--- Runs one local bootstrap step (a `bin/cosmic --make build`
--- invocation). `verbose` streams it verbatim — `stdout`/`stderr`
--- inherited, as every step ran before this flag existed. Quiet (the
--- default) instead captures it and prints only `summary_of` its
--- output on success, or everything captured, unfiltered, the moment
--- it fails — a failed bootstrap is never harder to read than a green
--- one used to be.
--- @param path string The worktree to run it in
--- @param argv {string} The full `bin/cosmic ...` argv
--- @param verbose boolean Stream the step verbatim instead of summarizing
--- @return boolean Whether the subprocess ran and exited successfully
--- @return string Failure diagnostic, empty on success
local function run_step(path: string, argv: {string}, verbose: boolean): boolean, string
  local r: child.Result
  local err: string
  if verbose then
    r, err = child.run(argv, {cwd = path, stdout = "inherit", stderr = "inherit"})
  else
    r, err = child.run(argv, {cwd = path})
  end
  local command = table.concat(argv, " ")
  if r == nil then return false, command .. ": " .. err end
  if not r.ok then
    if not verbose then print(r.stdout .. r.stderr) end
    if r.signal ~= nil then
      return false, ("%s failed (signal %d)"):format(command, r.signal)
    end
    return false, ("%s failed (exit %d)"):format(command, r.code)
  end
  if not verbose then
    for _, line in ipairs(summary_of(r.stdout)) do print(line) end
  end
  return true, ""
end

--- @return string Refusal, empty while the private runtime still matches
local function recheck(runtime: Runtime): string
  local text, err = verified(runtime.path, runtime.pin.digest)
  return text ~= nil and "" or ("private runtime changed: " .. err)
end

local function probe(runtime: Runtime, root: string): string
  local failures: {string} = {}
  for _, prefix in ipairs({{runtime.path}, {"sh", runtime.path}}) do
    local err = recheck(runtime)
    if err ~= "" then return err end
    local argv: {string} = {}
    for _, word in ipairs(prefix) do argv[#argv + 1] = word end
    argv[#argv + 1], argv[#argv + 2] = "-e", PROBE
    local r, rerr = child.run(argv, {cwd = root})
    if r ~= nil and r.ok and r.stdout == "gitboard-runtime-probe-v1\n" and r.stderr == "" then
      runtime.prefix = prefix
      local escaped: {string} = {}
      for _, word in ipairs(prefix) do escaped[#escaped + 1] = ("%q"):format(word) end
      print("runtime invocation: " .. table.concat(escaped, " "))
      return ""
    end
    if r == nil then failures[#failures + 1] = rerr
    else
      failures[#failures + 1] = ("probe failed: stdout=%q stderr=%q signal=%s exit=%s")
      :format(r.stdout, r.stderr, tostring(r.signal), tostring(r.code))
    end
  end
  return table.concat(failures, "; ") .. "; runtime retained at " .. runtime.path
end

--- @return Runtime | nil Verified preparation runtime, retained for final validation
--- @return string Preparation failure
local function prepare(source: string, root: string, pin: Pin, fetch: boolean,
    verbose: boolean): Runtime | nil, string
  local plans = profile.resolve(root).bootstrap
  local snapshot: string
  for _, path in ipairs({fs.join(root, "o/bootstrap/cosmic.ape"), fs.join(root, "o/bootstrap/cosmic"),
      fs.join(source, "o/bootstrap/cosmic.ape"), fs.join(source, "o/bootstrap/cosmic")}) do
    local text, err = verified(path, pin.digest)
    if text ~= nil then snapshot = text; print(("runtime cache hit %q"):format(path)); break end
    rejection(path, err)
  end
  if snapshot == nil and not fetch then
    return nil, "no verified runtime for sha256 " .. pin.digest .. "; use --fetch for explicit acquisition"
  end
  local out = fs.join(root, "o")
  local err = directory(root, out)
  if err ~= "" then return nil, err end
  local private = fs.join(out, ".gitboard-runtime-" .. rand.token())
  err = output_refusal(root, private, true)
  if err ~= "" then return nil, err end
  local made, merr = fs.make_dir(private, fs.octal("700"))
  if not made then return nil, merr end
  local path = fs.join(private, "cosmic")
  if snapshot == nil then
    err = output_refusal(root, path, false)
    if err ~= "" then return nil, err end
    print(("runtime product download: %q"):format(pin.url))
    local ok, derr = run_step(root, {"curl", "-q", "--fail", "--silent", "--show-error", "--location",
        "--max-redirs", "3", "--proto", "=https", "--proto-redir", "=https",
        "--connect-timeout", "10", "--max-time", "60", "--retry", "0", "--max-filesize",
        "268435456", "--output", path, pin.url}, verbose)
    if not ok then return nil, derr end
    snapshot, err = verified(path, pin.digest)
    if snapshot == nil then return nil, err end
    local mode, modeerr = fs.set_mode(path, fs.octal("700"))
    if not mode then return nil, modeerr end
  else
    err = write_new(root, path, snapshot)
    if err ~= "" then return nil, err end
  end
  local runtime: Runtime = {path = path, prefix = {}, pin = pin}
  err = recheck(runtime)
  if err ~= "" then return nil, err end
  err = publish(root, pin, snapshot)
  if err ~= "" then return nil, err end
  err = probe(runtime, root)
  if err ~= "" then return nil, err end
  for _, plan in ipairs(plans) do
    if fetch or plan[3] ~= "fetch" then
      err = recheck(runtime)
      if err ~= "" then return nil, err end
      local argv: {string} = {}
      for _, value in ipairs(runtime.prefix) do argv[#argv + 1] = value end
      for i = 2, #plan do argv[#argv + 1] = plan[i] end
      local ok, step = run_step(root, argv, verbose)
      if not ok then return nil, step .. "; retry retained builder with --adopt and optionally --fetch" end
    end
  end
  err = recheck(runtime)
  if err ~= "" then return nil, err end
  return runtime, ""
end

local record worktree_runtime
  type Pin = Pin
  type Runtime = Runtime
  inspect: function(path: string, commit: string): Pin | nil, string
  prepare: function(source: string, root: string, pin: Pin, fetch: boolean,
  verbose: boolean): Runtime | nil, string
  recheck: function(runtime: Runtime): string
  run_step: function(path: string, argv: {string}, verbose: boolean): boolean, string
end
local M: worktree_runtime = {inspect = inspect, prepare = prepare, recheck = recheck, run_step = run_step}
return M
