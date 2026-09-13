- 21 wraps at the producers listed: `check.must(proc.fork())` (×8),
  `check.must(proc.getsid(…))`, `check.must(proc.getpriority(…))` (×2),
  `check.must(fs.temp_dir(…))`, `check.must(json.encode(…))` (×3),
  `check.must(signal.sigprocmask(signal.SIG_BLOCK, …))` (×3),
  `check.must(hash.hash_password(…))`, and for `fd_test.tl:389–390`
  a fresh `local verify = check.must(f:read(100))` compared and
  printed in place of `data`.
- `fd_test.tl` 179, 219, 304, 383: widen the declaration to
  `number | nil` / `string | nil`. The asserts stay byte-identical;
  line 305 is a deliberate nil-branch test and is named in the PR
  as such.
- `codec_test.tl:203–204` → `local encoded =
  check.must(codec.encode_latin1(original))`, which asserts the same
  fact (encode succeeded) with the same error carried in the message;
  add `local check = require("cosmic.check")`. Name it in the PR.
- `proc_test.tl:68`'s `type(sid) == "number"` assert stays.
