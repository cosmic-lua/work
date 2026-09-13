Not a hard refusal — an orchestrator may still judge two specs
touching the same file are safe together (e.g. one only adds a test
fixture) and proceed; this only makes the fact visible instead of
requiring a manual `show`-by-show comparison across the whole
pullable set to discover it. Not a general dependency graph;
`blocked_by` edges remain the tool's only durable ordering.
