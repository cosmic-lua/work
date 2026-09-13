- Not fixing the nested-fence depth ceiling (cosmic-lua/cosmic#839,
  separate item) — this item is about *what* grant `run` and the
  mini-graph get, not the kernel/Landlock stacking limit uncovered
  while testing them.
- Not changing `record`'s existing grant shape.
- Does not resolve `engine.md`'s open "a channel for *I read this
  file* that is not `require`" question — the mini-graph's grant here
  can be derived from the closure the graph already computes, without
  that channel.
