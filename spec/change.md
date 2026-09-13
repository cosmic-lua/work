- The 20 `fs.read` producers → `local data = check.must(fs.read(…))`
  (`orig_data`/`new_data` likewise). Zero net lines in `embed_test.tl`.
- The 9 `time.format_*` producers →
  `local s = check.must(time.format_date(…))` etc.; add
  `local check = require("cosmic.check")` to `time_parse_test.tl`.
