- No change to any `re.*` binding — those are the four sibling
  captures filed alongside this one, a different fix family (tuple
  deviation, not raise-candidate), each blocked on `0YFj_out2`
  independently of this item.
- No change to `re.compile` or `argon2.hash_encoded` — census-verified
  tuple-exact, out of scope.
- Does not change `getopt_long()`'s own runtime outcome reporting
  (`result.unknown`/`result.missing`) — those already report through
  the success path and are untouched by this fix.
- No edit to `cosmic/flags/getopt.tl` or `cosmic/flags/parse.tl` in
  this item — that is `cosmic-lua/cosmic`, a different repo; note the
  follow-up, don't make it here.
