## Evidence

`gitboard publish <transaction> --execute` resolves its git push target from
`--dir` (default `$GITBOARD_DIR` else `.`, i.e. the process's cwd) — the
prepared ref names inside the transaction do not encode which repository
they belong to, only which local git checkout the caller happens to be
standing in when they run `publish`.

Hit directly, twice, in one session on 2026-09-10/11:

1. Orchestrator ran the printed recovery command for a `drop` transaction
   (`git push --atomic --force-with-lease=... origin ...`) from
   `/home/user/cosmic` (a *different* repository — cosmic-lua/cosmic, not
   the board's cosmic-lua/work) instead of `/home/user/work`:

```
$ pwd
/home/user/cosmic
$ git push --atomic --force-with-lease=refs/heads/items/3J91Fp7o...:d7bd8c89... origin ...
To https://github.com/cosmic-lua/cosmic
 ! [rejected]          ... -> claim-batches/89ecee478f2e25a39b9fc80334d48670 (atomic push failed)
 ! [rejected]          ... -> items/3J91Fp7o... (stale info)
error: failed to push some refs to 'https://github.com/cosmic-lua/cosmic'
```

Caught only because cosmic-lua/cosmic's own refs happened to collide/reject
outright (`atomic push failed`, `stale info`) — the error names the WRONG
repository (`cosmic-lua/cosmic`) with no hint that the caller's cwd, not
the transaction, decided that. Re-run from `/home/user/work` succeeded
against the correct repository (cosmic-lua/work).

2. An independent review agent (working item `3J8sXORr`) reported in its
   final message:

> `gitboard publish ... --execute` run without first `cd /home/user/work`
> ... still reported `published:` successfully with no error about wrong
> directory — I couldn't tell from the tool's output alone whether it
> resolved the right repo until the following `refresh --execute`
> explicitly confirmed my transaction ID.

In that case the wrong-directory push evidently found NO conflicting refs
to reject against, so `gitboard-publish: published: <id>` printed with no
indication that the local git repository it just pushed through was not
the board's own checkout. The only way the reviewer confirmed correctness
was a *subsequent* `refresh --execute`, several seconds and one more
process invocation later.

`publish`'s own help text (`gitboard help publish`, run 2026-09-11) makes
no mention of which local repository it resolves against beyond `--dir`'s
one-line default; nothing in its output ever names the git remote URL or
repository slug it pushed to.

## Non-goals

Not about `--dir`'s existing default-resolution rule itself (`$GITBOARD_DIR`
else cwd) — only about `publish` giving the caller no way to confirm,
before or immediately after `--execute`, which repository it just acted
against.
