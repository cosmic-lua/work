Write executable, GitBoard-shaped probes against `cosmic.template`'s
current public API to establish which of the following it already
meets cleanly, and which need a reusable capability addition:

- partial rendering (an absent field renders as something the caller
  can still find and fill, rather than the compile/render step
  refusing outright)
- absent-vs-empty values (the same distinction GitBoard's `fill`
  already draws)
- declared-field inspection and unresolved-field diagnostics (so a
  consumer can report what's missing without re-scanning the rendered
  body)
- literal inserted text that happens to look like template syntax,
  staying verbatim and never reinterpreted
- reusable sections (GitBoard appends the same friction-log section to
  every brief kind)
- generator-to-packaged-module integration (an ordinary `*_gen.tl`
  compiling templates into a strict, type-checked build, per work#103's
  approach)

For every requirement the probe proves is a real gap — not merely a
usage pattern GitBoard hasn't tried yet — implement a concrete
`cosmic.template` change: the failing consumer probe first, then the
public contract, tests, and documentation. Feed each resulting
capability back into `cosmic-lua/work#103` as it lands, rather than
batching everything behind one release.
