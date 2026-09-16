#!/usr/bin/env cosmic
local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local hash = require("cosmic.hash")
local cache = require("_work.runtime_cache")
local runtime = require("_work.worktree_runtime")
local SCRIPT < const > = [[#!/bin/sh
if [ "$1" = "-e" ]; then printf 'gitboard-runtime-probe-v1\n'; exit 0; fi
exit 0
]]
local record Case
  dir: string
  downloads: integer
  script: string
end

local function fresh(body: function(Case))
  local keys = {"XDG_CACHE_HOME", "HOME", "PATH", "GIT_CONFIG_GLOBAL", "GIT_CONFIG_NOSYSTEM", "GIT_CONFIG_SYSTEM"}
  local saved: {string: string} = {}
  for _, key in ipairs(keys) do saved[key] = env.get(key) end
  local run, link, remove, write, print_saved = child.run, fs.link, fs.remove, fs.write, _G.print
  local ok, err = pcall(function()
      local dir = check.must(fs.temp_dir(fs.join(fixture.tmpdir, "shared-runtime-XXXXXX")))
      assert(env.set("XDG_CACHE_HOME", fs.join(dir, "cache")))
      assert(env.set("HOME", dir))
      assert(env.set("GIT_CONFIG_GLOBAL", fs.join(dir, "gitconfig")))
      assert(env.set("GIT_CONFIG_NOSYSTEM", "1"))
      assert(env.unset("GIT_CONFIG_SYSTEM"))
      local c: Case = {dir = dir, downloads = 0, script = SCRIPT}
      child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
        if argv[1] == "curl" then
          c.downloads = c.downloads + 1
          assert(fs.write(argv[22], c.script))
          return {ok = true, code = 0, stdout = "", stderr = ""}, ""
        end
        return run(argv, opts)
      end
      body(c)
    end)
  child.run, fs.link, fs.remove, fs.write, _G.print = run, link, remove, write, print_saved
  for _, key in ipairs(keys) do
    if saved[key] == nil then assert(env.unset(key)) else assert(env.set(key, saved[key])) end
  end
  if not ok then error(err, 0) end
end

local function checkout(c: Case, name: string): string, runtime.Pin
  local root = fs.join(c.dir, name)
  assert(fs.make_dirs(fs.join(root, "bin")))
  fixture.git(root, {"init", "-q"})
  assert(fs.write(fs.join(root, ".gitignore"), "o/\n"))
  assert(fs.write(fs.join(root, "bin/cosmic"), "#!/bin/sh\nexit 99\n"))
  assert(fs.write(fs.join(root, "bin/cosmic.pin"), "url=https://example.test/runtime\nsha256=" .. hash.sha256_hex(c.script) .. "\n"))
  fixture.git(root, {"add", "."}); fixture.git(root, {"commit", "-qm", "fixture pin"})
  return root, check.must(runtime.inspect(root, "HEAD"))
end

local function prepare(c: Case, name: string, fetch?: boolean): runtime.Runtime, string
  local root, pin = checkout(c, name)
  return check.must(runtime.prepare(root, root, pin, fetch or false, false)), root
end

local function test_unrelated_checkouts_reuse_one_acquisition_changed_pin_and_forced_fetch()
  fresh(function(c: Case)
      local first = prepare(c, "one")
      local second = prepare(c, "two")
      assert(c.downloads == 1, "shared reuse guard: unrelated checkouts must acquire only once")
      assert(first.path ~= second.path and check.must(fs.read(second.path)) == SCRIPT)
      local old_entry = check.must(cache.entry(first.pin.digest))
      assert(check.must(fs.read(old_entry)) == SCRIPT)
      c.script = SCRIPT .. "# changed pin\n"
      local third = prepare(c, "three")
      assert(c.downloads == 2 and check.must(cache.entry(third.pin.digest)) ~= old_entry)
      local _forced, _root = prepare(c, "forced", true)
      assert(c.downloads == 3, "forced fetch must acquire despite a valid shared entry")
    end)
end

local function test_shared_digest_symlink_and_size_guards_reject_without_execution()
  for _, kind in ipairs({"digest", "symlink", "oversized"}) do
    fresh(function(c: Case)
        local path = check.must(cache.entry(hash.sha256_hex(SCRIPT)))
        assert(fs.make_dirs(fs.dirname(path)))
        if kind == "symlink" then
          local target = fs.join(c.dir, "raw")
          assert(fs.write(target, SCRIPT)); assert(fs.symlink(target, path))
        else
          assert(fs.write(path, kind == "digest" and SCRIPT .. "# untrusted\n" or SCRIPT))
          if kind == "oversized" then assert(fs.truncate(path, 268435457)) end
        end
        local r = prepare(c, "target")
        assert(c.downloads == 1, "shared digest/type/size guard: rejected entry must acquire")
        assert(check.must(fs.read(r.path)) == SCRIPT)
        if kind == "digest" then assert(check.must(fs.read(path)) == SCRIPT .. "# untrusted\n") end
        if kind == "symlink" then assert(check.must(fs.stat_link(path)):is_link()) end
        if kind == "oversized" then assert(check.must(fs.stat_link(path)):size() == 268435457) end
      end)
  end
end

local function test_concurrent_shared_winners_are_untouched_and_private_bytes_are_separate()
  for _, value in ipairs({SCRIPT, "invalid winner"}) do
    fresh(function(c: Case)
        local path = check.must(cache.entry(hash.sha256_hex(SCRIPT)))
        local link, temporary = fs.link, ""
        local lines: {string} = {}
        _G.print = function(...: any)
          for i = 1, select("#", ...) do lines[#lines + 1] = tostring((select(i, ...))) end
        end
        fs.link = function(old: string, new: string): boolean, string
          if new == path then temporary = old; assert(fs.write(path, value)) end
          return link(old, new)
        end
        local r = prepare(c, "target")
        assert(check.must(fs.read(path)) == value, "concurrent shared winner must remain untouched")
        assert(temporary ~= "" and not fs.is_present(temporary))
        assert((table.concat(lines):find("publication rejected", 1, true) ~= nil) == (value ~= SCRIPT))
        assert(fs.write(r.path, "private change"))
        assert(check.must(fs.read(path)) == value)
      end)
  end
end

local function test_cache_base_selection_and_unsafe_ancestors()
  fresh(function(c: Case)
      assert(env.set("XDG_CACHE_HOME", "relative"))
      assert(check.must(cache.entry("pin")) == fs.join(c.dir, ".cache/cosmic/runtime/pin/cosmic.ape"))
      assert(env.set("HOME", "relative"))
      local path, err = cache.entry("pin")
      assert(path == nil and err:find("unavailable", 1, true))
      assert(env.set("XDG_CACHE_HOME", fs.join(c.dir, "unsafe")))
      assert(fs.symlink(c.dir, fs.join(c.dir, "unsafe")))
      local rejected, rerr = cache.read(check.must(cache.entry("pin")), "pin")
      assert(rejected == nil and rerr:find("unsafe cache ancestor", 1, true))
      assert(cache.publish(check.must(cache.entry("pin")), "pin", SCRIPT):find("unsafe cache ancestor", 1, true))
    end)
end

local function test_actual_launcher_reuses_preparation_pristine_bytes_and_assimilates_only_copy()
  local launcher = check.must(fs.read("bin/cosmic"))
  fresh(function(c: Case)
      local native = fs.join(c.dir, "fixture-native")
      assert(fs.write(native, check.must(fs.read("/bin/echo"))))
      c.script = '#!/bin/sh\nif [ "$1" = "--assimilate" ]; then cp "' .. native .. '" "$0"; exit 0; fi\n'
      .. SCRIPT:sub(11)
      local r, prepared = prepare(c, "prepared")
      local raw = check.must(cache.entry(r.pin.digest))
      local tools = fs.join(c.dir, "tools")
      assert(fs.make_dir(tools))
      assert(fs.write(fs.join(tools, "curl"), "#!/bin/sh\necho forbidden-download >&2\nexit 91\n"))
      assert(fs.set_mode(fs.join(tools, "curl"), fs.octal("700")))
      assert(env.set("PATH", tools .. ":" .. check.must(env.get("PATH"))))
      local unrelated = checkout(c, "launcher-shared")
      for _, root in ipairs({prepared, unrelated}) do
        assert(fs.write(fs.join(root, "bin/cosmic"), launcher))
        local result = check.must(child.run({"sh", fs.join(root, "bin/cosmic"), "forwarded argument", "two"}))
        assert(result.ok and result.stdout == "forwarded argument two\n", "actual launcher must reuse without download: " .. result.stderr)
        assert(check.must(fs.read(fs.join(root, "o/bootstrap/cosmic.ape"))) == c.script)
        assert(check.must(fs.read(fs.join(root, "o/bootstrap/cosmic"))):sub(1, 4) == "\127ELF")
        assert(check.must(fs.read(raw)) == c.script, "shared representation must stay pristine")
        assert(not fs.is_present(fs.join(root, "o/bin/cosmic")))
      end
    end)
end

local function test_launcher_publication_exact_destination_and_error_suffix()
  local launcher = check.must(fs.read("bin/cosmic"))
  for _, kind in ipairs({"valid", "invalid", "directory", "symlink", "error"}) do
    fresh(function(c: Case)
        local native = fs.join(c.dir, "native")
        assert(fs.write(native, check.must(fs.read("/bin/echo"))))
        c.script = '#!/bin/sh\nif [ "$1" = "--assimilate" ]; then cp "' .. native .. '" "$0"; exit 0; fi\n'
        .. SCRIPT:sub(11)
        local root, pin = checkout(c, "launcher")
        assert(fs.write(fs.join(root, "bin/cosmic"), launcher))
        assert(fs.make_dirs(fs.join(root, "o/bootstrap")))
        assert(fs.write(fs.join(root, "o/bootstrap/cosmic.ape"), c.script))
        local path = check.must(cache.entry(pin.digest))
        local tools = fs.join(c.dir, "tools")
        assert(fs.make_dir(tools))
        local inject = kind == "valid" and 'cp "$1" "$2"'
        or kind == "directory" and 'mkdir "$2"'
        or kind == "symlink" and 'ln -s "' .. tools .. '" "$2"'
        or 'printf invalid > "$2"'
        local script = '#!/bin/sh\n' .. inject .. '\n'
        if kind == "error" then
          script = script .. 'echo "link: File exists in path: Permission denied" >&2\nexit 1\n'
        else script = script .. 'exec /usr/bin/link "$@"\n' end
        assert(fs.write(fs.join(tools, "link"), script))
        assert(fs.set_mode(fs.join(tools, "link"), fs.octal("700")))
        assert(env.set("PATH", tools .. ":" .. check.must(env.get("PATH"))))
        local result = check.must(child.run({"sh", fs.join(root, "bin/cosmic"), "argument"}))
        assert(result.ok == (kind ~= "error"), "launcher publication must distinguish actual link errors: " .. result.stderr)
        if kind == "valid" then assert(check.must(fs.read(path)) == c.script)
        elseif kind == "directory" then
          assert(check.must(fs.stat_link(path)):is_dir())
          local listing = check.must(child.run({"ls", "-A", path}))
          assert(listing.stdout == "", "directory winner must not receive a nested hard link")
        elseif kind == "symlink" then assert(check.must(fs.stat_link(path)):is_link())
        else assert(check.must(fs.read(path)) == "invalid") end
        if kind ~= "valid" and kind ~= "error" then
          assert(result.stderr:find("publication rejected", 1, true), "invalid winner must be diagnosed")
        end
      end)
  end
end

local function test_shared_publication_rehash_cleanup_and_link_errors()
  for _, kind in ipairs({"rehash", "cleanup", "File exists path"}) do
    fresh(function(_c: Case)
        local path = check.must(cache.entry(hash.sha256_hex(SCRIPT)))
        local link, remove = fs.link, fs.remove
        fs.link = function(old: string, new: string): boolean, string
          if new ~= path then return link(old, new) end
          if kind == "File exists path" then return false, "link: File exists path: EPERM: denied" end
          return link(old, new)
        end
        fs.remove = function(target: string): boolean, string
          if kind == "cleanup" and target:find("/.cosmic-", 1, true) then return false, "injected cleanup refusal" end
          return remove(target)
        end
        local err = cache.publish(path, hash.sha256_hex(SCRIPT), kind == "rehash" and "untrusted" or SCRIPT)
        assert(err ~= "", "cache staging, cleanup and non-EEXIST failures must be explicit")
        if kind == "rehash" then assert(not fs.is_present(path)) end
      end)
  end
end

local function test_launcher_candidate_and_copied_snapshot_guards_force_acquisition()
  local launcher = check.must(fs.read("bin/cosmic"))
  for _, kind in ipairs({"digest", "symlink", "oversized", "snapshot"}) do
    fresh(function(c: Case)
        local native, trusted = fs.join(c.dir, "native"), fs.join(c.dir, "trusted")
        assert(fs.write(native, check.must(fs.read("/bin/echo"))))
        c.script = '#!/bin/sh\nif [ "$1" = "--assimilate" ]; then cp "' .. native .. '" "$0"; exit 0; fi\n'
        .. SCRIPT:sub(11)
        assert(fs.write(trusted, c.script))
        local root, pin = checkout(c, "launcher")
        assert(fs.write(fs.join(root, "bin/cosmic"), launcher))
        local path = check.must(cache.entry(pin.digest))
        assert(fs.make_dirs(fs.dirname(path)))
        if kind == "symlink" then assert(fs.symlink(trusted, path))
        else
          assert(fs.write(path, kind == "digest" and c.script .. "# corrupt\n" or c.script))
          if kind == "oversized" then assert(fs.truncate(path, 268435457)) end
        end
        local tools, marker = fs.join(c.dir, "tools"), fs.join(c.dir, "downloaded")
        assert(fs.make_dir(tools))
        assert(fs.write(fs.join(tools, "curl"), '#!/bin/sh\nwhile [ "$1" != "-o" ]; do shift; done\n'
            .. 'cp "' .. trusted .. '" "$2"\nprintf yes > "' .. marker .. '"\n'))
        assert(fs.set_mode(fs.join(tools, "curl"), fs.octal("700")))
        if kind == "snapshot" then
          assert(fs.write(fs.join(tools, "cp"), '#!/bin/sh\n/bin/cp "$@"\nif [ "$1" = "' .. path
              .. '" ]; then printf "# modified snapshot\\n" >> "$2"; fi\n'))
          assert(fs.set_mode(fs.join(tools, "cp"), fs.octal("700")))
        end
        assert(env.set("PATH", tools .. ":" .. check.must(env.get("PATH"))))
        local result = check.must(child.run({"sh", fs.join(root, "bin/cosmic"), "argument"}))
        assert(result.ok, result.stderr)
        assert(fs.is_present(marker), "launcher candidate and snapshot digest guards must force acquisition")
        assert(check.must(fs.read(fs.join(root, "o/bootstrap/cosmic.ape"))) == c.script)
      end)
  end
end
