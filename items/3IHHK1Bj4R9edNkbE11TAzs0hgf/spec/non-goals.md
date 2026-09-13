- **No change to integer encoding or decoding.** The `lua_isinteger`
  branch and `ljson.c` both stay exactly as they are: an
  integer-shaped token in range IS an integer; the encoder simply
  stops producing such tokens for floats.
- **No change to `DoubleToLua` / `EncodeLua`.** Its `1000000.`
  goldens stay; it is a separate converter with its own flags.
- **No `EncodeJson` signature or option change.** No new option to
  select the old spelling, and no band check that would make the rule
  conditional.
- **Do not touch cosmic in this PR.** Retiring cosmic's `_fuzz`
  float bound needs a released cosmos pin carrying this fix, so it is
  a separate item under this parent, blocked on this one.
- The string-byte round-trip observation from cosmic (bytes above
  `0x7f` decode as UTF-8 pairs) is a different subject and is that
  module's stated contract, not a defect — do not touch
  `SerializeString` or the decoder's string path.
- No drive-by reformatting: the fork stays mergeable with upstream
  jart/cosmopolitan, so the diff is these four files and nothing else.
