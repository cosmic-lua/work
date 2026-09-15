No SessionStart hook. Warming the cache before the first question is a
different change with a different failure mode (a hook that downloads on every
session start costs more than it saves when the session never asks) and is not
decided here.

No pruning of superseded cache entries, and no sharing of the cache between the
two binaries beyond the common directory.

The pin format, the pin files themselves, and the `download`/`verify_sha256`
helpers are unchanged.
