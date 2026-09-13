- Do not attempt the full 2.26-to-3.6 server migration (gh#187) here —
  this fix repairs a bug in the existing 2.26-linked server so #187's
  "fix #184 in the process (or confirm 3.6's server-side parser doesn't
  have the crash)" prerequisite is satisfied without waiting on the
  full port.
- Do not add SNI-based virtual hosting behavior changes beyond the null
  check — `TlsRouteFind`'s matching logic (common name / SAN / IP) is
  unrelated to this bug and untouched.
- Do not file this upstream to `jart/cosmopolitan` as part of this
  item — the issue body already flags that as a follow-up worth doing
  once root-caused; leave that as a separate decision for whoever lands
  the fix, since this repo has no cross-org GitHub access to open the
  issue there itself.
