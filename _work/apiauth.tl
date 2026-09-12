--- The one explicit opt-in that gives `_work.api` a live provider
--- transport. gitboard's default stays a local refusal: `_work.api`
--- installs `no_transport`, never inspects the environment, and never
--- loads this module — a caller who wants real provider calls in this
--- process requires it by name and asks for them.
---
--- The ask is two levels deep on purpose. `GITBOARD_PROVIDER_TOKEN_ENV`
--- carries the NAME of the variable holding the token, so gitboard
--- never guesses which variable is a credential: a token sitting in a
--- host environment under one of the conventional provider names is
--- picked up only when the caller says so. No name, no transport, and
--- no name written down here to fall back to.
---
--- The token is read once, held only by the closure the installed
--- transport carries, and sent only as that request's `authorization`
--- header. It is never printed, logged, returned in a message, or
--- written to the `o/` cache. Nor is any other value read out of the
--- environment: a refusal names `GITBOARD_PROVIDER_TOKEN_ENV` and
--- stops there, because a caller who pastes the token itself into that
--- variable rather than a variable's name would otherwise have it
--- echoed back by the refusal.
local deep = require("cosmic.deep")
local env = require("cosmic.env")
local fetch = require("cosmic.fetch")

local api = require("_work.api")

--- The variable a caller sets to the NAME of the variable holding the
--- token. Its own value is a variable name, never a credential.
local ACTIVATION_ENV < const > = "GITBOARD_PROVIDER_TOKEN_ENV"

--- What `_work.api`'s `M.transport` field holds: `cosmic.fetch.fetch`'s
--- own shape, so an installed transport is a drop-in for the refusal it
--- replaces.
local type Transport = function(url: string, opts: fetch.Options):
fetch.Response | nil, fetch.Error

--- Reads one environment variable by name. `cosmic.env.get` in
--- production; a test passes its own reader so no case here depends on
--- the host's real environment.
local type Lookup = function(name: string): string | nil

--- Whether a string is shaped like an environment variable name. A
--- caller that names something else (a path, a token, an empty word)
--- asked for nothing this module can read.
--- @param name string The candidate name
--- @return boolean True when it is a plain variable name
local function is_env_name(name: string): boolean
  return name:match("^[A-Za-z_][A-Za-z0-9_]*$") ~= nil
end

--- Build the transport that carries `token`. The request goes out with
--- the bearer credential added to whatever headers `_work.api` built
--- for it; every other field of the call is untouched. The token lives
--- in this closure and nowhere else — which is why the request is sent
--- on a COPY of the caller's options: writing the credential into the
--- table the caller still holds would leave it readable there after
--- the call returns, and the closure would no longer be the only
--- place it lives.
--- @param token string The provider token, sent as a bearer credential
--- @param send Transport | nil What performs the request (defaults to
--- `cosmic.fetch.fetch`); a test passes a capture instead
--- @return Transport The transport to install on `_work.api`
local function transport_for(token: string, send?: Transport): Transport
  local perform = send or fetch.fetch
  return function(url: string, opts: fetch.Options):
    fetch.Response | nil, fetch.Error
    local sent = deep.copy(opts)
    local headers = sent.headers or {}
    headers["authorization"] = "Bearer " .. token
    sent.headers = headers
    return perform(url, sent)
  end
end

-- What `_work.api`'s transport was before the first `activate` in this
-- process installed over it, so `deactivate` can put it back. nil means
-- nothing is installed: either no activation has happened, or the one
-- that did has already been undone. Nested activations do not stack —
-- this holds the transport from BEFORE the outermost one, which is the
-- state a scoped caller means to restore.
local saved: Transport | nil = nil

--- Install a live transport on `_work.api` when, and only when, the
--- caller has named the variable holding its token. Every other
--- outcome leaves `_work.api` exactly as it loads: refusing. Nothing
--- is written to disk and no value read from the environment appears
--- in the returned message.
--- @param lookup Lookup | nil Environment reader (defaults to
--- `cosmic.env.get`)
--- @param send Transport | nil What the installed transport performs
--- requests with (defaults to `cosmic.fetch.fetch`)
--- @return boolean True when a live transport was installed
--- @return string Why nothing was installed, "" on success
local function activate(lookup?: Lookup, send?: Transport): boolean, string
  local read = lookup or env.get
  local named = read(ACTIVATION_ENV)
  if named == nil or named == "" then
    return false, ("no provider transport requested: set %s to the name of "
      .. "the environment variable holding the token"):format(ACTIVATION_ENV)
  end
  if not is_env_name(named) or named == ACTIVATION_ENV then
    return false, ("%s must hold the name of another environment variable")
    :format(ACTIVATION_ENV)
  end
  local token = read(named)
  if token == nil or token == "" then
    return false, ("the environment variable %s names is unset or empty")
    :format(ACTIVATION_ENV)
  end
  if saved == nil then
    saved = api.transport
  end
  api.transport = transport_for(token, send)
  return true, ""
end

--- Undo `activate`: put back the transport `_work.api` carried before
--- it, so a caller that wanted live provider calls for one step leaves
--- the process refusing again afterward. Activation is otherwise
--- permanent and process-wide, which no caller wanting a scoped write
--- can live with. Idempotent: with nothing installed it restores
--- nothing and says so.
--- @return boolean True when an installed transport was removed
local function deactivate(): boolean
  local prior = saved
  if prior == nil then
    return false
  end
  api.transport = prior
  saved = nil
  return true
end

local record apiauth
  type Transport = Transport
  type Lookup = Lookup
  --- The variable naming the variable that holds the token.
  ACTIVATION_ENV: string
  transport_for: function(token: string, send?: Transport): Transport
  activate: function(lookup?: Lookup, send?: Transport): boolean, string
  deactivate: function(): boolean
end

local M: apiauth = {
  ACTIVATION_ENV = ACTIVATION_ENV,
  transport_for = transport_for,
  activate = activate,
  deactivate = deactivate,
}

return M
