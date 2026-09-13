Make a build that cannot see a generator's output fail loudly rather than
pass. The scan that feeds the graph must account for files a generator
writes into the tree during that same run — either by re-scanning after
the generation phase when a generator reported writes, or by refusing
with a message naming the generator and the files it wrote too late,
rather than silently building without them.

State the rule in the guide the project's generators are written
against: whether a `*_gen.tl` may write into the tree at all, and if so
what the build guarantees about its output being seen in the same run.
The current text ("generators run before the graph") reads as a promise
that this case violates.

Add a case: a project whose generator writes a new module into the tree
builds correctly in ONE run, or fails with a message naming the cause —
not a PASS with the module missing from the artifact.
