--- The trust root's pin and the runtime pin name ONE cosmic release:
--- the cosmic that builds gitboard is the cosmic gitboard is built
--- onto, so a pin bump moves both lines together or the ratchet says so.
local fs = require("cosmic.fs")
local literal = require("cosmic.literal")

local TRUST_PIN < const > = "bin/cosmic.pin"
local RUNTIME_PIN < const > = "3p/cosmic/cosmic_pin.tl"

local record RuntimePin
  url: string
  version: string
  platforms: {string: {string: string}}
  format: string | nil
end

local function trust_fields(): {string: string}
  local text = assert(fs.read(TRUST_PIN))
  local out: {string: string} = {}
  for line in text:gmatch("[^\n]+") do
    local k, v = line:match("^(%w+) *= *(.+)$")
    if k then
      out[k] = v
    end
  end
  return out
end

local function runtime_pin(): RuntimePin
  local value = assert(literal.parse_file(RUNTIME_PIN))
  return value as RuntimePin -- cast: a literal pin parses to a plain table this record names
end

local function test_runtime_pin_is_the_trust_root_release()
  local trust = trust_fields()
  local rp = runtime_pin()
  local tag = trust.url:match("/download/([^/]+)/cosmic%-lua$")
  assert(tag, "trust pin url does not name a cosmic-lua release: " .. tostring(trust.url))
  assert(rp.version == tag, ("runtime pin version %s is not the trust root's %s"):format(
      tostring(rp.version), tag))
  local sha = rp.platforms["*"].sha
  assert(sha == trust.sha256, ("runtime pin sha %s is not the trust root's %s"):format(
      tostring(sha), tostring(trust.sha256)))
  assert(rp.url:match("/cosmic%-lua$"), "runtime pin does not name the cosmic-lua asset")
end

local function test_runtime_pin_is_formatless_so_the_asset_lands_untouched()
  local rp = runtime_pin()
  assert(rp.format == nil, "the runtime pin must not unpack: the asset IS the runtime")
end
