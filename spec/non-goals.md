Not proposing a new tool or capability for subagents to self-schedule
wakeups — that infrastructure question is out of this item's scope,
and the ban above makes it moot for GitHub events specifically: a
subagent is never the right place for that subscription regardless of
what wakeup mechanism it might someday have. This is a documentation/
process fix: state the existing division of labor (orchestrator polls
or subscribes, agent acts) explicitly and as a hard rule for this
specific failure mode, so a future orchestrator session doesn't repeat
the same five-times-expensive pattern this pass did, and no session
ever spawns an agent that subscribes to a PR on its own.
