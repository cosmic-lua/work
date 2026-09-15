`skills/work/SKILL.md`'s bootstrap fetches two refs:

```
git -C "$BOARD" fetch --atomic origin \
  '+refs/heads/state:refs/remotes/origin/state' \
  '+refs/heads/board/format:refs/remotes/origin/board/format'
```

A checkout bootstrapped that way can READ the board but cannot WRITE to it.
The archive validator treats the three legacy namespaces as never-fetched
and refuses every composition until they are present. Measured on a fresh
sibling `../work` clone, 2026-09-15:

```
archive: refs/heads/claim-batches not fetched — 542 of 542 witness refs absent locally
archive: refs/heads/ended not fetched — 723 of 723 witness refs absent locally
archive: refs/heads/items not fetched — 725 of 725 witness refs absent locally
archive: removed refs/heads/board/seq
```

The first `claim` of the session fails on this, after the bootstrap has
reported success — so the gap surfaces several verbs later, at the point
the session is trying to do real work.

Extend the bootstrap snippet to fetch all of it in the one call that is
already there:

```
git -C "$BOARD" fetch --atomic origin \
  '+refs/heads/state:refs/remotes/origin/state' \
  '+refs/heads/board/*:refs/remotes/origin/board/*' \
  '+refs/heads/items/*:refs/remotes/origin/items/*' \
  '+refs/heads/ended/*:refs/remotes/origin/ended/*' \
  '+refs/heads/claim-batches/*:refs/remotes/origin/claim-batches/*'
```

Measured cost of the full fetch on this host: 5.9s wall for ~1,990 refs, a
one-time cost per clone. Say in the surrounding prose that the legacy
namespaces are witness refs the archive check reads, so the next reader
knows why a format-6 board still fetches format-5 refs.

Also state the repository mapping step, which the bootstrap omits entirely
and which `claim` likewise refuses without:

```
git -C "$BOARD" config --local --add gitboard.repository \
  cosmic-lua/cosmic=/absolute/path/to/cosmic
```
