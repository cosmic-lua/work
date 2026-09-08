--- Per-run claim identity. Gitboard mints an opaque 128-bit id; the caller
--- carries it explicitly across later processes (and in an offline bundle).
--- No ambient user, host, credential, or provider identity participates.
local codec = require("cosmic.codec")
local rand = require("cosmic.rand")

local function mint(): string
  return codec.encode_hex(rand.bytes(16))
end

local function is_id(value: string): boolean
  return value ~= nil and #value == 32 and value:match("^[0-9a-f]+$") ~= nil
end

local record claimsession
  mint: function(): string
  is_id: function(value: string): boolean
end

local M: claimsession = {mint = mint, is_id = is_id}
return M
