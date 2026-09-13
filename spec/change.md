Same shape as `Ba69_burI`: determine whether `finger.*` is a binding
that was removed and never cleaned up downstream (check binding-removal
history the way `tool/lua/test_cosmo.lua:89` documented
`VisualizeControlCodes`'s removal) or one that was never wired up in
the demo despite being documented. Fix `tool/net/demo/.init.lua`,
`tool/net/demo/finger.lua`, and `help.txt`'s FINGER MODULE section to
be consistent with whichever direction the binding's actual state
supports — restore the binding, or remove the demo/`help.txt`
references, matching `Ba69_burI`'s resolution pattern.
