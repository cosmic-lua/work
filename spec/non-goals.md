- No determinism work; that is its own item.
- No change to how NULL arrives (`lua_pushnil` is correct and cosmic's
  nil-flow doctrine already covers it).
- No wrapper type, no bind-dispatch change, and no other
  `cosmic.sqlite` work in this item — see Follow-up above.
- No fix or test for the `SQLITE_INTEGER` string fallback — it is
  dead code on this build (see Evidence above), not a defect to
  settle here or in any follow-up.
