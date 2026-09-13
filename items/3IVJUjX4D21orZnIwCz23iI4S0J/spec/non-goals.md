- No change to `flow.built_by` itself: prefix awareness for
  orchestrator waves is 3IVJVZJt, mergeable independently (different
  files; this diff only calls the function).
- No change to `next`'s routing (`_work/action.tl` already consults
  `built_by`) or to the review-claim path (`gitreview`).
- No change to the unnamed-session stance: an empty `session` is still
  not refused — a repair written without one still works.
