Resolve `paths_named`'s relative tokens the way the headroom lines now
do: against a checkout of the item's own repository, at a known commit
rather than a working tree. Where the two need the same resolution, share
it rather than writing it a second time.

When no checkout of the item's repo is available, the collision check
must degrade honestly — say it could not be checked, the way
`not checked:` already does for headroom — rather than silently answering
from the running directory.

Add cases: a token present in the item's repo but absent from the running
directory is found, and the reverse is not; and an item whose repo has no
local checkout reports the degraded answer rather than a confident one.
