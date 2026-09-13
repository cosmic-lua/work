`tool/net/help.txt`, the `unix.wait` example and any prose describing
its return shape: rewrite to the `unix.WaitResult` table shape `#340`
introduced (`result.pid`, `result.wstatus`, `result.rusage` on
success; `nil, error, errno` on failure), matching
`tool/net/definitions.lua`'s `unix.WaitResult` doc block. Land as its
own PR in `cosmic-lua/cosmopolitan`, the same convention `#339`
followed after `#338` — documentation only, no binding or
`definitions.lua` change.
