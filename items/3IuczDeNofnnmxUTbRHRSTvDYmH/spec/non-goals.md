This container does not choose the final verb name or commit to JSON over
another structured encoding. It is not a performance item: the observed cost
is oversized and repeated output, not slow SQLite queries.

Its first slice is filed as a child: a `show --summary` rollup by state and
repo. That slice deliberately does not settle this container's open questions —
it adds one rollup to the verb that already exists, leaving the verb name and
the encoding undecided here.

The cost this container names has a measurement now. Answering "what is open"
took `show` (8 todo rows), then `show --todo 0` (245 rows), then a written
script to group 274 rendered rows by state and repo — three calls and an
ad-hoc aggregation for a four-line answer. The read verbs render rows; nothing
renders a shape.
