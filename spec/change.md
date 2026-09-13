`tool/net/lzip.c`:
- `kLuaZip[]` (line 2190): add `{"reader", LuaZipOpenReader}` alongside
  the existing `open`/`from`/`create`/`append`/`validate_name` entries.
  No change to `LuaZipOpenReader` itself — it already has the right
  signature and behavior.

`tool/net/definitions.lua`:
- Add a `zip.reader` annotation immediately after `zip.open`'s block,
  mirroring `zip.create`'s existing shape exactly:

  ```
  --- Opens a ZIP archive for reading. This is equivalent to
  --- `zip.open(path, "r", options)`.
  ---@param path string|integer Path to the ZIP file, or file descriptor
  ---@param options? zip.OpenOptions Optional settings
  ---@return zip.Reader? reader ZIP reader object on success
  ---@return string? error Error message on failure
  ---@nodiscard
  function zip.reader(path, options) end
  ```

- `test_definitions_coverage.lua`'s existing `add("zip.", C_zip,
  "kLuaZip")` (line 1362) auto-discovers every `kLuaZip[]` entry and
  requires an annotation — no new test wiring needed, the ratchet
  already covers this the moment `reader` is registered.

Gate with `make -j$(nproc) o//tool/lua/test`.
