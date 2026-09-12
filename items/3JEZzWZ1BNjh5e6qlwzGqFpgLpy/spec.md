# Decide: cosmic.http's concurrency model — fork-per-connection as redbean, a thread pool of lua_States, or a poll loop (research item)

## Goal

Settle G7's other half as a `docs/decisions/` record and file the
build items: how `cosmic.http` serves more than one connection at a
time without changing the `Handler` signature the core child fixed.
This is a research item (`gitboard help bar`: "research is an item
whose deliverable is recorded findings and follow-up items, not code")
because the choice turns on measured facts the tree does not have yet
and on a product decision nobody has made.

## Evidence

The three serious shapes, and the facts a record must carry for each:

1. **fork-per-connection** — redbean's model (`tool/net/redbean.c`:
   `HandleMessages` at `:6355` runs in a forked worker; the accept loop
   forks). Portable including Windows via cosmopolitan's fork, isolation
   for free, `cosmic.sandbox` applies per worker; cost is a fork per
   accept and no shared in-process state (the todo fixture's table
   stops working — every app needs SQLite or `cosmic.shm`). Measure:
   fork latency on Linux/macOS/Windows with `cosmic.proc.fork`, and the
   requests/sec delta against the baseline.
2. **a thread pool, one `lua_State` per worker** — needs a
   cosmopolitan-side binding (pthreads exist in the libc; nothing
   creates a second Lua state from Lua today: `grep -rn 'lua_newthread\|
   luaL_newstate' tool/net/*.c tool/lua/*.c` at research time), a
   message-passing story between states (strings only, or `cosmic.shm`),
   and a decision on what a handler may share. Highest throughput,
   largest surface.
3. **a single-threaded poll loop** — `cosmic.poll` exists
   (`cosmic/poll.tl`); non-blocking sockets (`Socket:set_nonblocking`,
   `cosmic/net/socket.tl:131`) and a per-connection parser
   (`cosmo.http.parser` is one per connection by design, `reset`
   between messages) make an event loop possible with no C change;
   handlers must not block (no `child.run`, no slow SQLite) or the
   whole server stalls — the same rule Node has. Lowest surface, weakest
   guarantee.

D9's consequence binds: "`net`/`poll`/`shm` designs should not paint
the server story into a corner" — the record must say which of the
three those designs already fit.

## Change

Ready when: `ls _perf/bench/http_server_bench.tl` prints `_perf/bench/http_server_bench.tl`.

That is the baseline child merged; a concurrency decision without a
single-connection baseline cannot be compared. Today the command
reports the path as missing.

Deliverables, no product code:

1. Measure: the fork cost per platform (a 20-line script under
   `_perf/` is fine, not committed unless it becomes a scenario), the
   baseline scenario's numbers, and the poll-loop shape's numbers from
   a throwaway branch if it can be prototyped in under a session.
2. Write `docs/decisions/d<next>-http-concurrency-model.md` per
   `skills/decide/SKILL.md`: the three options each with the reason it
   lost or won, the measured numbers, and the consequence for
   `Handler` (unchanged) and for what a handler may assume about
   shared state.
3. File the build items under this container as children of this item's
   parent, ranked after it, file-disjoint where possible; for a fork or
   thread model the cosmopolitan-side binding is its own item with the
   `definitions.lua` rule named.

## Non-goals

- Building any of the three.
- HTTP/2, which would reopen this.

## Access

- cosmic-lua/cosmic: read+write (`docs/decisions/`).
- cosmic-lua/cosmopolitan: read-only.
