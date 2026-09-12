## Evidence

`cosmic --make build` can report PASS while producing a binary that
cannot run, when a `*_gen.tl` writes modules into the tree.

Observed by `«uOsC_KV6H»`'s reviewer in cosmic-lua/work at
`4c5edb1e`, where `_work/brieftmpl_gen.tl` generates nine modules under
`_work/brieftmpl/`. With that directory moved aside:

    $ bin/cosmic --make build
    build: PASS (234 files, 1 binary)

    $ ./o/bin/gitboard help
    module '_work.brieftmpl.fields' not found
      at /zip/_work/briefcontext.lua:37

234 files, not the 243 a correct build reports. The generator DID run and
DID write the nine modules into the tree — but the project scan had
already been taken, so the newly written files were not in the graph and
not embedded. A second `--make build` recovers, reporting 243 and
producing a working binary.

So the generator writes in-tree one generation too late for the scan that
consumes its output. The verb's own contract — "generators run before the
graph" — holds for generators that write into `o/`, whose output the graph
reads through the include path; it does not hold for one whose output must
be SEEN by the project scan as source.

The failure mode is the dangerous combination: a green verdict line, a
non-zero file count that looks plausible, and a binary that dies on its
first module load. Nothing in the build output distinguishes it from a
correct build.

Committing the generated modules is what keeps cosmic-lua/work out of this
hole today — a clean checkout already has them, so the first scan sees
them and the generator is a fixpoint (verified: a fresh clone of that SHA
builds 243 files, working binary, clean `git status`). The hazard is
therefore latent rather than live there, and reachable by anyone who adds
a tree-writing generator, or whose generated files are absent for any
reason.

## Change

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

## Non-goals

Not changing where `*_gen.tl` output conventionally goes (`o/<stem>/`
stays the default), and not forbidding tree-writing generators as part of
this item — if that is the answer, it is a decision record, not a silent
behaviour change. Not touching `cosmic-lua/work`'s own generator, which
is a downstream consumer of whatever this settles.

## Access

cosmic-lua/cosmic, read and write on a branch; no other repository.
