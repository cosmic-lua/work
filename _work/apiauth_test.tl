#!/usr/bin/env cosmic
-- The explicit opt-in behind `_work.api`'s transport. Two halves: the
-- default — loading the opt-in, and asking for an activation nobody
-- requested — leaves the codec refusing exactly as it loads; and a
-- caller that names the variable holding its token gets a transport
-- carrying that token as a bearer credential. Every case names its own
-- fake variable and fabricates its own response, so nothing here reads
-- an ambient credential, spends a real one, or makes a live call.

local env = require("cosmic.env")
local fetch = require("cosmic.fetch")

local api = require("_work.api")
local apiauth = require("_work.apiauth")

--- Set one variable and return what to restore it to.
--- @param name string The variable
--- @param value string The value to set
--- @return string | nil The prior value, nil when it was unset
local function stub_env(name: string, value: string): string | nil
  local prior = env.get(name)
  assert(env.set(name, value))
  return prior
end

--- Put a variable back the way `stub_env` found it.
--- @param name string The variable
--- @param prior string | nil What `stub_env` returned
local function restore_env(name: string, prior: string | nil)
  if prior == nil then
    local _ok, _err = env.unset(name)
  else
    assert(env.set(name, prior))
  end
end

--- Whether `_work.api` still refuses without doing I/O — the fact the
--- default path is built on.
--- @return boolean True when the codec refuses locally
local function still_refuses(): boolean
  local res, err = api.call("GET", "/user", "")
  return res == nil and err:find("external to gitboard", 1, true) ~= nil
end

-- Requiring the opt-in is not asking for it: the module loads, reads
-- nothing, and leaves the codec's local refusal in place.
local function test_loading_the_opt_in_installs_nothing()
  assert(still_refuses(), "loading _work.apiauth must not wire a transport")
end

-- No named variable is no request, and a request nobody made installs
-- nothing — the refusal names the variable to set, and the codec is
-- untouched.
local function test_activate_refuses_when_no_variable_is_named()
  local before = api.transport
  local ok, err = apiauth.activate(function(_name: string): string | nil
      return nil
    end)
  assert(not ok, "an unrequested activation installs nothing")
  assert(err:find(apiauth.ACTIVATION_ENV, 1, true) ~= nil, "got: " .. err)
  assert(api.transport == before, "the codec's transport must be untouched")
  assert(still_refuses(), "got a transport without asking for one")
end

-- A named variable that holds nothing is a caller mistake, not a
-- licence to go looking elsewhere for a token.
local function test_activate_refuses_when_the_named_variable_is_empty()
  local before = api.transport
  local ok, err = apiauth.activate(function(name: string): string | nil
      if name == apiauth.ACTIVATION_ENV then return "GITBOARD_TEST_ABSENT_VAR" end
      return nil
    end)
  assert(not ok, "an empty credential variable installs nothing")
  assert(err:find("unset or empty", 1, true) ~= nil, "got: " .. err)
  assert(api.transport == before, "the codec's transport must be untouched")
end

-- A value that is not a variable name is refused rather than treated
-- as one — including the module's own variable, which would name
-- itself.
local function test_activate_refuses_a_value_that_is_not_a_variable_name()
  local ok, err = apiauth.activate(function(name: string): string | nil
      if name == apiauth.ACTIVATION_ENV then return "/etc/token file" end
      return "unused"
    end)
  assert(not ok, "a path is not a variable name")
  assert(err:find("name of another environment variable", 1, true) ~= nil,
    "got: " .. err)
  local self_named, serr = apiauth.activate(function(name: string): string | nil
      if name == apiauth.ACTIVATION_ENV then return apiauth.ACTIVATION_ENV end
      return "unused"
    end)
  assert(not self_named, "the naming variable must not name itself")
  assert(serr:find("name of another environment variable", 1, true) ~= nil,
    "got: " .. serr)
end

-- A caller that pastes the token itself into the naming variable must
-- not have it read back out in the refusal: no value read from the
-- environment ever reaches a message.
local function test_a_refusal_never_echoes_a_value_read_from_the_environment()
  local pasted = "ghp_averyfaketokenvalue"
  local ok, err = apiauth.activate(function(name: string): string | nil
      if name == apiauth.ACTIVATION_ENV then return pasted end
      return nil
    end)
  assert(not ok, "a token is not a variable name to read from")
  assert(err:find(pasted, 1, true) == nil, "the refusal leaked a value: " .. err)
end

-- The whole opt-in, through the real environment: the caller names the
-- variable holding its token, and the codec's next call goes out
-- through a live-shaped transport carrying that token as a bearer
-- credential. The request is captured rather than sent, so the shape is
-- proven with no network at all.
local function test_activate_wires_a_transport_carrying_the_named_token()
  local before = api.transport
  local prior_name = stub_env(apiauth.ACTIVATION_ENV, "GITBOARD_TEST_FAKE_VAR")
  local prior_token = stub_env("GITBOARD_TEST_FAKE_VAR", "fake-token-value")
  local seen_url = ""
  local seen: fetch.Options = nil
  local ok, err = apiauth.activate(nil,
    function(url: string, opts: fetch.Options):
      fetch.Response | nil, fetch.Error
      seen_url, seen = url, opts
      return {status = 200, headers = {}, raw_headers = {}, body = "{}",
        url = url} as fetch.Response, nil -- cast: a fabricated response, not a real Fetch return
    end)
  local res, cerr = api.call("GET", "/user", "")
  api.transport = before
  restore_env("GITBOARD_TEST_FAKE_VAR", prior_token)
  restore_env(apiauth.ACTIVATION_ENV, prior_name)
  assert(ok, "got: " .. err)
  assert(res ~= nil, "got: " .. tostring(cerr))
  assert(res.status == 200, "got: " .. tostring(res.status))
  assert(seen_url == "https://api.github.com/user", "got: " .. seen_url)
  assert(seen.headers["authorization"] == "Bearer fake-token-value",
    "got: " .. tostring(seen.headers["authorization"]))
  assert(seen.headers["accept"] == "application/vnd.github+json",
    "the codec's own headers survive: " .. tostring(seen.headers["accept"]))
end

-- An ambient credential is not an activation. With a token sitting in
-- the environment under the name gitboard used to read, and no naming
-- variable set, the codec still refuses.
local function test_an_ambient_credential_alone_activates_nothing()
  local before = api.transport
  local prior_name = env.get(apiauth.ACTIVATION_ENV)
  local _unset, _uerr = env.unset(apiauth.ACTIVATION_ENV)
  local prior_token = stub_env("GITHUB_TOKEN", "must-not-be-used")
  local ok, err = apiauth.activate()
  restore_env("GITHUB_TOKEN", prior_token)
  restore_env(apiauth.ACTIVATION_ENV, prior_name)
  assert(not ok, "an ambient token must not activate anything")
  assert(err:find("no provider transport requested", 1, true) ~= nil,
    "got: " .. err)
  assert(api.transport == before, "the codec's transport must be untouched")
  assert(still_refuses(), "an ambient token got itself installed")
end
