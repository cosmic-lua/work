#!/usr/bin/env cosmic
local check = require("cosmic.check")
local child = require("cosmic.child")
local env = require("cosmic.env")
local fd = require("cosmic.fd")
local fixture = require("_work.fixture")
local fs = require("cosmic.fs")
local hash = require("cosmic.hash")
local runtime = require("_work.worktree_runtime")
local SCRIPT < const > = [[#!/bin/sh
if [ "$1" = "-e" ]; then printf 'gitboard-runtime-probe-v1\n'; exit 0; fi
printf '%s\n' "$*" >> o/steps
echo 'build: PASS (fixture)'
]]
local record Case
  source: string
  root: string
  pin: runtime.Pin
  lines: {string}
end

local function fresh(name: string, body: function(Case), script?: string)
  local run, link, move, remove, open, mode = child.run, fs.link, fs.move, fs.remove, fd.open, fs.set_mode
  local print_saved, write, stat = _G.print, fs.write, fs.stat_fd
  local keys = {"GIT_CONFIG_GLOBAL", "GIT_CONFIG_NOSYSTEM", "GIT_CONFIG_SYSTEM"}
  local saved: {string: string} = {}
  for _, key in ipairs(keys) do saved[key] = env.get(key) end
  local ok, err = pcall(function()
      assert(env.set("GIT_CONFIG_GLOBAL", fs.join(fixture.tmpdir, "gitconfig-empty")))
      assert(env.set("GIT_CONFIG_NOSYSTEM", "1"))
      assert(env.unset("GIT_CONFIG_SYSTEM"))
      local dir = check.must(fs.temp_dir(fs.join(fixture.tmpdir, "runtime-" .. name .. "-XXXXXX")))
      local source, root = fs.join(dir, "source"), fs.join(dir, "target")
      assert(fs.make_dirs(fs.join(source, "bin")))
      fixture.git(source, {"init", "-q"})
      assert(fs.write(fs.join(source, ".gitignore"), "o/\n"))
      assert(fs.write(fs.join(source, "bin/cosmic"), "#!/bin/sh\nexit 99\n"))
      local bytes = script or SCRIPT
      assert(fs.write(fs.join(source, "fixture-runtime"), bytes))
      local pin = "url = https://example.test/runtime\nsha256 = " .. hash.sha256_hex(bytes) .. "\n"
      assert(fs.write(fs.join(source, "bin/cosmic.pin"), pin))
      fixture.git(source, {"add", "."})
      fixture.git(source, {"commit", "-qm", "target"})
      fixture.git(source, {"worktree", "add", "-q", "--detach", root, "HEAD"})
      local c: Case = {source = source, root = root, pin = check.must(runtime.inspect(root, "HEAD")), lines = {}}
      _G.print = function(...: any)
        for i = 1, select("#", ...) do c.lines[#c.lines + 1] = tostring((select(i, ...))) end
      end
      body(c)
    end)
  child.run, fs.link, fs.move, fs.remove, fd.open, fs.set_mode = run, link, move, remove, open, mode
  _G.print, fs.write, fs.stat_fd = print_saved, write, stat
  for _, key in ipairs(keys) do
    if saved[key] == nil then assert(env.unset(key)) else assert(env.set(key, saved[key])) end
  end
  if not ok then error(err, 0) end
end

local function cache(root: string, name?: string, text?: string)
  assert(fs.make_dirs(fs.join(root, "o/bootstrap")))
  assert(fs.write(fs.join(root, "o/bootstrap", name or "cosmic"), text or SCRIPT))
end

local function prepare(c: Case, fetch?: boolean): runtime.Runtime
  local r, err = runtime.prepare(c.source, c.root, c.pin, fetch or false, false)
  assert(r ~= nil, err)
  return r
end

local function failed(c: Case, needle: string, fetch?: boolean)
  local r, err = runtime.prepare(c.source, c.root, c.pin, fetch or false, false)
  assert(r == nil and err:find(needle, 1, true) ~= nil, err)
end

local function test_target_pin_and_order_ignore_source_pin_stamps_and_assimilated_bytes()
  fresh("order", function(c: Case)
      cache(c.root, "cosmic.ape", "corrupt")
      cache(c.root, "cosmic", "assimilated")
      cache(c.source, "cosmic.ape")
      cache(c.source, "cosmic", "bad")
      cache(c.source, "cosmic.pin", c.pin.digest)
      assert(fs.write(fs.join(c.source, "bin/cosmic.pin"), "wrong source pin"))
      fixture.git(c.source, {"add", "bin/cosmic.pin"})
      fixture.git(c.source, {"commit", "-qm", "source pin is not target authority"})
      local r = prepare(c)
      assert(r.path ~= fs.join(c.source, "o/bootstrap/cosmic.ape"))
      assert(check.must(fs.read(r.path)) == SCRIPT)
      assert(check.must(fs.read(fs.join(c.root, "o/bootstrap/cosmic.ape"))) == "corrupt")
      assert(check.must(fs.read(fs.join(c.root, "o/steps"))) == "--make build\n")
      local lines = table.concat(c.lines, "\n")
      assert(lines:find("sha256 mismatch", 1, true) and lines:find("runtime cache hit", 1, true))
    end)
end

local function test_missing_corrupt_symlink_cache_never_executes_or_downloads_without_fetch()
  for _, kind in ipairs({"missing", "corrupt", "symlink", "directory"}) do
    fresh(kind, function(c: Case)
        if kind == "corrupt" then cache(c.source, nil, "touch invalid-runtime-marker")
        elseif kind == "symlink" then
          assert(fs.make_dirs(fs.join(c.source, "o/bootstrap")))
          assert(fs.symlink(fs.join(c.source, "fixture-runtime"), fs.join(c.source, "o/bootstrap/cosmic")))
        elseif kind == "directory" then assert(fs.make_dirs(fs.join(c.source, "o/bootstrap/cosmic"))) end
        local original = child.run
        child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
          assert(argv[1] == "git", "no execution/acquisition on an unverified cache miss")
          return original(argv, opts)
        end
        failed(c, "--fetch")
        assert(not fs.is_present(fs.join(c.root, "invalid-runtime-marker")))
        assert(not fs.is_present(fs.join(c.root, "o")))
      end)
  end
end

local function test_snapshot_survives_source_replacement_and_private_change_is_detected()
  for _, mutate_private in ipairs({false, true}) do
    fresh("snapshot", function(c: Case)
        cache(c.source)
        local original = child.run
        child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
          if argv[2] == "-e" then
            assert(fs.write(fs.join(c.source, "o/bootstrap/cosmic"), "untrusted replacement"))
            local result, err = original(argv, opts)
            if mutate_private then assert(fs.write(argv[1], "changed after probe")) end
            return result, err
          end
          return original(argv, opts)
        end
        if mutate_private then failed(c, "private runtime changed")
        else
          local r = prepare(c)
          assert(check.must(fs.read(r.path)) == SCRIPT)
        end
      end)
  end
end

local function test_concurrent_publication_never_overwrites_and_unlinks_only_its_temporary()
  for _, winner in ipairs({"sentinel", SCRIPT}) do
    fresh("race", function(c: Case)
        cache(c.source)
        local destination, temporary = fs.join(c.root, "o/bootstrap/cosmic.ape"), ""
        local link, move = fs.link, fs.move
        local function inject(old: string, new: string)
          if new == destination then
            temporary = old
            assert(fs.write(destination, winner))
          end
        end
        fs.link = function(old: string, new: string): boolean, string inject(old, new); return link(old, new) end
        fs.move = function(old: string, new: string): boolean, string inject(old, new); return move(old, new) end
        local r, err = runtime.prepare(c.source, c.root, c.pin, false, false)
        assert(check.must(fs.read(destination)) == winner, "never overwrite the concurrent winner")
        assert(r ~= nil, err)
        assert(temporary ~= "" and not fs.is_present(temporary))
        assert(r.path ~= destination and check.must(fs.read(r.path)) == SCRIPT)
        assert((table.concat(c.lines):find("sha256 mismatch", 1, true) ~= nil) == (winner ~= SCRIPT))
        assert(fs.write(r.path, "private modified later"))
        assert(check.must(fs.read(destination)) == winner, "publication is not linked to execution inode")
      end)
  end
end

local function test_publication_vanished_unreadable_and_other_errors_preserve_destination()
  for _, kind in ipairs({"vanished", "unreadable", "other", "unlink"}) do
    fresh(kind, function(c: Case)
        cache(c.source)
        local destination, temporary = fs.join(c.root, "o/bootstrap/cosmic.ape"), ""
        local link, remove, open = fs.link, fs.remove, fd.open
        fs.link = function(old: string, new: string): boolean, string
          -- Two bootstrap targets now publish in sequence; only the first
          -- (this test's own `destination`) is under test here — the
          -- second's real, unmocked link must proceed normally.
          if new ~= destination then return link(old, new) end
          temporary = old
          if kind == "other" then return false, "injected EPERM" end
          if kind == "vanished" or kind == "unreadable" then
            assert(fs.write(destination, "winner"))
            local ok, err = link(old, new)
            assert(not ok, err)
            if kind == "vanished" then assert(remove(destination)) end
            return ok, err
          end
          return link(old, new)
        end
        fd.open = function(path: string, flags: integer, mode?: integer, dirfd?: integer): fd.Handle | nil, string
          if kind == "unreadable" and path == destination then return nil, "injected read refusal" end
          return open(path, flags, mode, dirfd)
        end
        fs.remove = function(path: string): boolean, string
          if kind == "unlink" and path == temporary then return false, "injected unlink failure" end
          return remove(path)
        end
        if kind == "other" then failed(c, "EPERM")
        elseif kind == "unlink" then failed(c, "cleanup failed")
        else
          prepare(c)
          assert(table.concat(c.lines):find("runtime rejected", 1, true))
        end
        assert(temporary ~= "")
        assert(fs.is_present(temporary) == (kind == "unlink"))
        if kind == "unreadable" then assert(check.must(fs.read(destination)) == "winner") end
        if kind == "unlink" then assert(check.must(fs.read(destination)) == SCRIPT) end
      end)
  end
end

local function test_publication_errno_looking_paths_do_not_hide_real_link_failure()
  fresh("EEXIST: misleading", function(c: Case)
      cache(c.source)
      local link, temporary, failure = fs.link, "", ""
      fs.link = function(old: string, new: string): boolean, string
        temporary = old
        assert(fs.move(old, old .. ".hidden"))
        local ok, err = link(old, new)
        assert(fs.move(old .. ".hidden", old))
        local prefix = "link: " .. old .. " -> " .. new .. ": ENOENT: "
        assert(not ok and err:sub(1, #prefix) == prefix, err)
        failure = err
        return ok, err
      end
      local r, err = runtime.prepare(c.source, c.root, c.pin, false, false)
      assert(r == nil and err == failure and failure ~= "", "real ENOENT must fail despite EEXIST path text")
      assert(temporary ~= "" and not fs.is_present(temporary), "publication temporary must be removed")
      assert(not fs.is_present(fs.join(c.root, "o/bootstrap/cosmic.ape")))
      assert(not fs.is_present(fs.join(c.root, "o/steps")), "publication failure must precede execution")
    end)
end

local function test_probe_native_shell_fallback_and_failures()
  for _, kind in ipairs({"native", "shell", "wrong-output", "both", "signal"}) do
    local script = kind == "wrong-output" and "#!/bin/sh\necho wrong\n" or SCRIPT
    fresh(kind, function(c: Case)
        cache(c.source, nil, script)
        local original, attempts = child.run, 0
        child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
          if argv[2] == "-e" or argv[3] == "-e" then
            attempts = attempts + 1
            if kind == "both" or (kind == "shell" and argv[1] ~= "sh") then return nil, "cannot execute" end
            if kind == "signal" then return {ok = false, code = -1, signal = 15, stdout = "", stderr = ""}, "" end
          end
          return original(argv, opts)
        end
        if kind == "both" or kind == "wrong-output" or kind == "signal" then
          failed(c, kind == "signal" and "signal=15" or "runtime retained at")
          assert(attempts == 2)
        else
          local r = prepare(c)
          assert((r.prefix[1] == "sh") == (kind == "shell"))
          assert(attempts == (kind == "shell" and 2 or 1))
          assert(check.must(fs.read(fs.join(c.root, "o/bootstrap/cosmic.ape"))) == SCRIPT)
        end
      end, script)
  end
end

local function test_download_exact_bounded_argv_and_cache_hit_before_fetch()
  for _, kind in ipairs({"download", "mismatch", "cached", "failed"}) do
    fresh(kind, function(c: Case)
        if kind == "cached" then cache(c.source) end
        local original, downloads = child.run, 0
        child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
          if argv[1] == "curl" then
            downloads = downloads + 1
            local expected = {"curl", "-q", "--fail", "--silent", "--show-error", "--location", "--max-redirs", "3",
              "--proto", "=https", "--proto-redir", "=https", "--connect-timeout", "10", "--max-time", "60",
              "--retry", "0", "--max-filesize", "268435456", "--output", argv[22], c.pin.url}
            assert(table.concat(argv, "\0") == table.concat(expected, "\0") and opts.cwd == c.root)
            assert(table.concat(c.lines):find("runtime product download", 1, true))
            if kind == "failed" then return nil, "download spawn failure" end
            assert(fs.write(argv[22], kind == "mismatch" and "corrupt download" or SCRIPT))
            return {ok = true, code = 0, stdout = "", stderr = ""}, ""
          end
          if argv[#argv] == "fetch" then
            assert(kind ~= "cached" or table.concat(c.lines):find("runtime cache hit", 1, true))
          end
          return original(argv, opts)
        end
        if kind == "mismatch" then failed(c, "sha256 mismatch", true)
        elseif kind == "failed" then failed(c, "download spawn failure", true)
        else
          prepare(c, true)
          assert(check.must(fs.read(fs.join(c.root, "o/steps"))) == "--make fetch\n--make build\n")
        end
        assert(downloads == (kind == "cached" and 0 or 1))
      end)
  end
end

local function test_pin_grammar_and_committed_working_agreement()
  local digest = hash.sha256_hex(SCRIPT)
  local good = {"url=https://example.test/x\nsha256=" .. digest,
    " \t# comment\r\n\r\nsha256 \t= " .. digest .. "\t\r\nurl = https://example.test/x\r\n"}
  local bad = {"url=https://u:p@example.test/x\nsha256=" .. digest,
    "url=http://example.test/x\nsha256=" .. digest, "url=https://example.test/x # comment\nsha256=" .. digest,
    "url=https://example.test/x\nsha256=" .. digest:upper(), "url=https://example.test/x\nsha256=" .. digest .. "\nextra=x",
    "url=https://example.test/x\nsha256=" .. digest .. "\nsha256=" .. digest,
    "url=https://example.test/x\\\nsha256=" .. digest, "url=\nsha256=" .. digest,
    "url=https://example.test/x\nsha256=" .. digest .. "\0", string.rep("x", 16385),
    "url=https://example.test/x\nsha256=" .. digest .. "\r"}
  for _, valid in ipairs({true, false}) do
    for _, text in ipairs(valid and good or bad) do
      fresh("pin", function(c: Case)
          assert(fs.write(fs.join(c.root, "bin/cosmic.pin"), text))
          fixture.git(c.root, {"add", "."}); fixture.git(c.root, {"commit", "-qm", "pin grammar"})
          local p, err = runtime.inspect(c.root, "HEAD")
          assert((p ~= nil) == valid, err)
        end)
    end
  end
  fresh("pin-mismatch", function(c: Case)
      assert(fs.write(fs.join(c.root, "bin/cosmic.pin"), "wrong working bytes"))
      local p, err = runtime.inspect(c.root, "HEAD")
      assert(p == nil and err:find("differs", 1, true))
    end)
end

local function test_output_symlink_nonignored_tracked_and_io_refusals()
  for _, kind in ipairs({"symlink", "nonignored", "tracked", "write", "read", "mode"}) do
    fresh(kind, function(c: Case)
        cache(c.source)
        if kind == "symlink" then assert(fs.symlink(c.source, fs.join(c.root, "o")))
        elseif kind == "nonignored" then assert(fs.write(fs.join(c.root, ".gitignore"), ""))
        elseif kind == "tracked" then
          cache(c.root, "cosmic.ape")
          fixture.git(c.root, {"add", "-f", "o/bootstrap/cosmic.ape"})
        end
        local open = fd.open
        fd.open = function(path: string, flags: integer, mode?: integer, dirfd?: integer): fd.Handle | nil, string
          if kind == "write" and (flags & fd.O_CREAT) ~= 0 then return nil, "injected write failure" end
          if kind == "read" and path:find(".gitboard-runtime-", 1, true) and flags == (fd.O_RDONLY | fd.O_NOFOLLOW | fd.O_NONBLOCK) then
            return nil, "injected staged read failure"
          end
          return open(path, flags, mode, dirfd)
        end
        if kind == "mode" then
          -- Force acquisition to exercise downloaded-file permission failure.
          assert(fs.remove(fs.join(c.source, "o/bootstrap/cosmic")))
          local original = child.run
          child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
            if argv[1] == "curl" then
              assert(fs.write(argv[22], SCRIPT))
              return {ok = true, code = 0, stdout = "", stderr = ""}, ""
            end
            return original(argv, opts)
          end
          fs.set_mode = function(_path: string, _mode: integer): boolean, string return false, "injected mode failure" end
        end
        failed(c, kind == "symlink" and "unsafe output ancestor" or kind == "tracked" and "tracked preparation output"
          or kind == "nonignored" and "non-ignored" or "injected", kind == "mode")
      end)
  end
end

local function test_pin_nonregular_missing_untracked_and_unreadable_never_downgrade()
  for _, kind in ipairs({"symlink", "directory", "untracked", "dangling", "unreadable", "absent"}) do
    fresh("pin-" .. kind, function(c: Case)
        local path = fs.join(c.root, "bin/cosmic.pin")
        if kind == "unreadable" then
          local open = fd.open
          fd.open = function(p: string, flags: integer, mode?: integer, dirfd?: integer): fd.Handle | nil, string
            if p == path then return nil, "pin read refused" end
            return open(p, flags, mode, dirfd)
          end
        else
          fixture.git(c.root, {"rm", "-q", "bin/cosmic.pin"})
          if kind == "symlink" then assert(fs.symlink("../fixture-runtime", path))
          elseif kind == "directory" then
            assert(fs.make_dir(path)); assert(fs.write(fs.join(path, "child"), "wrong"))
          end
          fixture.git(c.root, {"add", "."}); fixture.git(c.root, {"commit", "-qm", "pin shape"})
          if kind == "untracked" then assert(fs.write(path, c.pin.text))
          elseif kind == "dangling" then assert(fs.symlink("missing-target", path)) end
        end
        local p, err = runtime.inspect(c.root, "HEAD")
        assert(p == nil and (err == "") == (kind == "absent"), kind .. ": " .. err)
      end)
  end
end

local function test_probe_stderr_and_build_signal_fail_with_complete_quiet_diagnostics()
  for _, mode in ipairs({"stderr", "signal"}) do
    fresh(mode, function(c: Case)
        cache(c.source)
        local original = child.run
        child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
          if mode == "stderr" and (argv[2] == "-e" or argv[3] == "-e") then
            return {ok = true, code = 0, stdout = "gitboard-runtime-probe-v1\n", stderr = "probe warning"}, ""
          end
          if mode == "signal" and argv[#argv] == "build" then
            return {ok = false, code = -1, signal = 15, stdout = "complete stdout", stderr = "complete stderr"}, ""
          end
          return original(argv, opts)
        end
        failed(c, mode == "stderr" and "probe warning" or "signal 15")
        if mode == "signal" then assert(table.concat(c.lines):find("complete stdoutcomplete stderr", 1, true)) end
      end)
  end
end

local function test_bounded_cache_and_staged_hash_checks_are_real()
  fresh("bounded", function(c: Case)
      cache(c.source)
      assert(fs.truncate(fs.join(c.source, "o/bootstrap/cosmic"), 268435457))
      failed(c, "--fetch")
    end)
  fresh("staged-hash", function(c: Case)
      cache(c.source)
      local open = fd.open
      fd.open = function(path: string, flags: integer, mode?: integer, dirfd?: integer): fd.Handle | nil, string
        if path:find(".gitboard-runtime-", 1, true) and flags == (fd.O_RDONLY | fd.O_NOFOLLOW | fd.O_NONBLOCK) then
          assert(fs.write(path, "corrupt staged copy"))
        end
        return open(path, flags, mode, dirfd)
      end
      failed(c, "sha256 mismatch")
    end)
end

local function test_probe_cannot_remove_the_advertised_build_plan()
  fresh("plans", function(c: Case)
      cache(c.source)
      local original = child.run
      child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
        local r, err = original(argv, opts)
        if argv[2] == "-e" then assert(fs.remove(fs.join(c.root, "bin/cosmic"))) end
        return r, err
      end
      prepare(c)
      assert(check.must(fs.read(fs.join(c.root, "o/steps"))) == "--make build\n")
    end)
end

local function test_failed_empty_git_reads_never_become_absent_pin_or_safe_output()
  for _, command in ipairs({"ls-tree", "cat-file", "ls-files"}) do
    fresh("git-error", function(c: Case)
        cache(c.source)
        local original = child.run
        child.run = function(argv: {string}, opts?: child.Options): child.Result | nil, string
          if argv[1] == "git" and argv[2] == command then
            return {ok = false, code = -1, signal = 15, stdout = "", stderr = ""}, ""
          end
          return original(argv, opts)
        end
        if command == "ls-files" then failed(c, "git failed")
        else
          local pin, err = runtime.inspect(c.root, "HEAD")
          assert(pin == nil and err:find("git failed", 1, true), "failed read is not a legacy pin absence")
        end
        assert(not fs.is_present(fs.join(c.root, "o")))
      end)
  end
end
