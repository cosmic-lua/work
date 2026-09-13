Same shape as `Ba69_burI` (#378) and `3IptmlaFwaGNOmguaiefU6lyGKY` (#379):
confirm live (build `o//tool/net/redbean-demo`, hit whatever route serves
`tool/net/demo/maxmind.lua`, confirm the exact 500) and determine whether
`maxmind.*` is a binding that was removed and never cleaned up downstream,
or one that was never wired up despite being documented — check binding
history the way `tool/lua/test_cosmo.lua:89` documents `VisualizeControlCodes`'s
removal. Fix `tool/net/demo/maxmind.lua`, `tool/net/help.txt`'s MAXMIND
MODULE section, and `tool/net/BUILD.mk`'s embed list to be consistent with
whichever direction the binding's actual state supports — restore the
binding, or remove the demo/`help.txt`/BUILD.mk references, matching the
prior two items' resolution pattern.
