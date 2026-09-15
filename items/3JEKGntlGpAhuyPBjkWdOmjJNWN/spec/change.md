The bootstrap block in `skills/work/SKILL.md` (cosmic-lua/cosmic) names a
deprecated no-op:

    bin/gitboard sync                                       # every session

`grep -n "bin/gitboard sync" skills/work/SKILL.md` -> line 37.

`sync` is deprecated — it writes ``gitboard-sync: deprecated; use `gitboard
refresh` `` to stderr (`grep -n 'gitboard-sync: deprecated' _work/gitboard.tl`
in cosmic-lua/work). But `refresh --execute` is NOT the replacement a fresh
checkout can use, and this spec previously said it was. Measured on a clone
matching what a session harness produces (default branch only, no
`refs/remotes/origin/state`, no `refs/heads/board/format`):

    git clone --single-branch --branch main <board> probe

    bin/gitboard sync --dir probe ; echo "exit=$?"
    no board format marker in this checkout — fetch it: 'git' 'fetch' '--atomic' 'origin' '+refs/heads/state:refs/remotes/origin/state' '+refs/heads/board/format:refs/remotes/origin/board/format'; `gitboard init` is only for a board that does not exist yet
    exit=1

    bin/gitboard refresh --execute --dir probe ; echo "exit=$?"
    (byte-identical refusal)
    exit=1

    cd probe && git for-each-ref --format='%(refname)' | grep -E 'state|format'
    (no output — nothing was fetched)

Both exit 1 and neither fetches: the format gate runs before `--execute`'s
fetch, so the verb that fetches refuses until the board has been fetched.
Writing `refresh --execute` into the skill as the every-session command would
hand every new session a command that fails on its first run.

Rewrite the bootstrap block to what works today. Keep the existing clone line
and the `SSL_USE_SYSTEM_CERTS` paragraph unchanged. Replace the `sync` line
with:

- one sentence saying a sibling `../work` supplied by a session harness carries
  only the default branch, so the board refs are fetched once, in that
  checkout;
- that fetch, exactly as the tool's own refusal composes it:

      git fetch --atomic origin \
        '+refs/heads/state:refs/remotes/origin/state' \
        '+refs/heads/board/format:refs/remotes/origin/board/format'

- then `bin/gitboard refresh --execute` as the recurring every-session command,
  which is correct once the refs exist.

Also replace `sync` in the "start every session with `sync`" sentence under
"## then let the tool teach" (`grep -n "start every session with" skills/work/SKILL.md`),
and sweep for any other bare invocation:
`grep -n 'gitboard sync' skills/work/SKILL.md skills/work/decompose.md`.
