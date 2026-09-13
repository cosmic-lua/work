Not a general policy for near-cap files — that is `AY6h_bM0B`'s scope
("spec bar: flag a Change-named file already within ~20 lines of the
500-line cap"), already filed. This item is the one concrete unblock
`HlNE_YWL2` needs.

Not writing `HlNE_YWL2`'s four new test bodies: the behavior they assert
(`cmd_attach` taking `repo`/`base` parameters, `cmd_new`'s tightened
parent gate) does not exist until `HlNE_YWL2`'s own Change (its steps 1-4,
still `todo`) lands — a test for it would fail today. This item only opens
the file and the headroom they will land in, and repoints `HlNE_YWL2`'s
spec at it.

Not touching `_work/gitgraph.tl`: it has 75 lines of headroom today (see
Evidence) and none of its source moves — `cmd_attach`/`cmd_new` stay put;
only their tests are regrouped, matching `gitclaim_test.tl`'s precedent of
a topic-named test file with no matching source module.
