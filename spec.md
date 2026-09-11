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

Re-measured 2026-09-11, and one correction to reading 2 above: the
`bin/gitboard` trust-root script in a cosmic-lua/cosmic checkout already
exports `GITBOARD_DIR` when the caller has not, resolving it to the
sibling `../work` clone whenever that clone's `origin` is cosmic-lua/work
(`bin/gitboard`, the `probe_sibling_of` / `is_work_origin` block). So a
`gitboard publish` run through that script does resolve the right
checkout regardless of cwd:

```
$ cd /home/user/cosmic && bin/gitboard help publish | grep -- --dir
      --dir DIR      state repository checkout (default: $GITBOARD_DIR, else .) (default: /home/user/work)
$ cd /home/user/cosmic && bin/gitboard publish
gitboard-publish: REFUSED: select exactly one prepared transaction or draft; one publish is one atomic push
$ cd /home/user/work && /home/user/cosmic/bin/gitboard publish
gitboard-publish: REFUSED: select exactly one prepared transaction or draft; one publish is one atomic push
```

The defect the readings above actually establish is therefore the
SILENCE, not the resolution: `publish` never tells the caller which
checkout or which remote URL it resolved, so neither a correct
resolution nor an incorrect one is visible at the moment it matters.

## Change

Make `gitboard publish` name the repository it is about to push to, on
both of its output paths, in `_work/gittransport.tl`. One printed line;
no argv, exit code, or verdict wording changes.

**What publish prints today**

Measured 2026-09-11 against a scratch remote-backed board built under
the session scratchpad (`git init --bare origin.git`; `git init clone`;
`git remote add origin ...`; `gitboard init --remote`; push the seed
refs; `gitboard refresh --execute`; `gitboard new "scratch measurement
item"`), driven by the pinned release `o/bootstrap/gitboard` that
`bin/gitboard` execs, with `GITBOARD_DIR` pointed at the clone:

```
$ GITBOARD_DIR="$S/clone" "$GB" publish
git push --atomic --force-with-lease=refs/heads/items/3JAKNpN953BMdIetGv2of0dz2It: origin 7d280a9504a6e1e26416dc592f51bd0eccae397d:refs/heads/items/3JAKNpN953BMdIetGv2of0dz2It
gitboard-publish: rendered 1 exact atomic leased push command(s); nothing executed
=== exit 0

$ GITBOARD_DIR="$S/clone" "$GB" publish --execute
published: cba341ec2e68398d2d67075c784c9ba4d19cd81c-42e4efc400f4ba9a
gitboard-publish: CONFIRMATION PENDING: 1 prepared transaction batch(es) pushed. Run `gitboard refresh --execute --remote origin`; a pushed claim is not safe to act on until refresh reports confirmed
=== exit 2
```

Neither path names the checkout or a URL. `origin` is the only clue, and
`origin` is whatever the resolved `--dir` happens to have configured.

**The source change**

`_work/gittransport.tl` is 374 lines (`wc -l _work/gittransport.tl` ->
`374 _work/gittransport.tl`), so there is room under the 500-line cap.

1. Add `local fs = require("cosmic.fs")` to the require block at the top
   of the file (lines 5 to 11 today). `store` is already required there:
   `grep -n '^local store = require' _work/gittransport.tl` ->
   `11:local store = require("_work.store")`.

2. Add one file-local helper immediately above `cmd_publish`
   (`grep -n 'local function cmd_publish' _work/gittransport.tl` ->
   `123:local function cmd_publish(s: store.Store, selectors: {string}, remote: string,`):

```teal
--- The URL the configured remote resolves to in this checkout — the
--- repository an executed publish actually writes to, and the one fact
--- neither the rendered argv nor the `published:` line carries.
--- `--push` falls back to the fetch URL when no separate push URL is
--- configured, so it is never less correct than the plain read.
--- @param s store.Store The store
--- @param remote string The remote name the push argv names
--- @return string The URL, or a readable stand-in when git cannot read it
local function remote_push_url(s: store.Store, remote: string): string
  local r = store.git(s, {"remote", "get-url", "--push", remote})
  if r == nil or not r.ok then
    return ("unreadable (no %s remote in this checkout)"):format(remote)
  end
  return (r.stdout:gsub("%s+$", ""))
end
```

   `store.git` is the established way to run a local git read against the
   store's root: `grep -n '^local function git' _work/store.tl` ->
   `120:local function git(s: Store, argv: {string}): child.Result | nil, string`,
   and `_work/publish.tl:36` already calls it in exactly this shape
   (`local r = store.git(s, {"remote"})`, then `r ~= nil and r.ok`). It
   runs with `cwd = s.root`, reads only local configuration, and performs
   no transport — so it stays safe under `_work/gitcli_quarantine_test.tl`'s
   `offline_capture`, which stubs `prepared.execute` to raise
   (`sed -n 44,54p _work/gitcli_quarantine_test.tl`).

   The helper is infallible by type (a bare `string`), so it adds no
   nil-admitting return and no cast.

3. In `cmd_publish`, immediately before `local failed = 0`
   (`grep -n 'local failed = 0' _work/gittransport.tl` ->
   `164:  local failed = 0`), print exactly one line:

```teal
  print(("target: dir=%s remote=%s url=%s"):format(
      fs.absolute_path(s.root), remote, remote_push_url(s, remote)))
```

   `fs.absolute_path(p: string): string` is infallible —
   `bin/cosmic --docs cosmic.fs` -> `function absolute_path(p: string): string`,
   "Convert relative path to absolute by prepending cwd. Does NOT resolve
   symlinks" — and `_work/brief.tl:363` already applies it to `s.root`.

   Line 164 is the one correct site: it sits after every refusal
   (`no prepared transactions` at 128, the multi-unit refusal at 131, the
   `bound to remote` refusal at 135) and after the
   `refs.board_mode(s.root) == "local"` branch has returned at 139..163,
   and before the single loop that both renders
   (`196:      print(render_argv(argv))`) and executes
   (`189:        print(("published: %s"):format(plan.id))`). So the line
   prints exactly once per invocation, only when a real remote push is on
   the table, and above both the rendered argv and the `published:` line.

   `remote` is already the effective remote name: `_work/gitboard.tl:209`
   to `:214` calls `refs.use_remote(dir, explicit_remote)` for an explicit
   `--remote` before falling back to `refs.board_remote(dir)`, and passes
   the result into `transport.cmd_publish` at `:248`.

**The bound, as a test in the diff**

`_work/gitcli_transport_test.tl` (303 lines;
`wc -l _work/gitcli_transport_test.tl` -> `303`) is one of the only two
files that drive the `publish` verb through `gitboard.main`:
`grep -rln 'capture("publish"' _work/*_test.tl` ->
`_work/gitcli_quarantine_test.tl`, `_work/gitcli_transport_test.tl`. Put
both assertions there; it already requires `check`, `fixture`, `fs`,
`prepared`, `refs` and `store`, so no new require is needed.

Extend the existing render test,
`test_publish_defaults_to_an_exact_render_without_moving_refs`
(`grep -n 'test_publish_defaults_to_an_exact_render_without_moving_refs'
_work/gitcli_transport_test.tl` -> `210` and `230`), with one assertion
after its `assert(code == 0, out)`:

```teal
  assert(out:find("target: dir=" .. fs.absolute_path(s.root)
      .. " remote=origin url=", 1, true), out)
```

Then add one test for the `--execute` path, after line 230, over a
fixture that has a real remote to push to:

```teal
local function test_publish_execute_names_the_repository_it_pushed_to()
  local _s1, s2 = fixture.init_shared("cli-publish-target")
  local root = s2.root
  local _closed, _cerr = store.close(s2)
  local new_code, new_out = capture("new", "execute target", "--dir", root)
  assert(new_code == 0, new_out)
  local bare = fs.join(fixture.tmpdir, "verbs-shared-cli-publish-target",
    "remote.git")
  local code, out = capture("publish", "--execute", "--dir", root)
  assert(code == 2, out)
  local target_at = out:find("target: dir=" .. fs.absolute_path(root)
    .. " remote=origin url=" .. bare, 1, true)
  local published_at = out:find("published: ", 1, true)
  assert(target_at ~= nil and published_at ~= nil, out)
  assert(target_at < published_at,
    "the target line must print above published:\n" .. out)
end
test_publish_execute_names_the_repository_it_pushed_to()
```

The fixture facts this leans on, each read from `_work/fixture.tl`:

- `init_shared(name)` returns two remote-mode clones over one bare
  remote, and names that bare remote
  `fs.join(tmpdir, "verbs-shared-" .. name, "remote.git")` —
  `sed -n 82,110p _work/fixture.tl` (`local base = fs.join(tmpdir,
  "verbs-shared-" .. name)`, `local bare = fs.join(base, "remote.git")`,
  `git(base, {"clone", "-q", bare, dir2})`), with `tmpdir` exported as
  `fixture.tmpdir` (`_work/fixture.tl:25`).
- `fixture.file_item` is deliberately NOT used to leave work for
  `publish`: it calls `caller_publish(s)` itself
  (`sed -n '/^local function file_item/,/^end/p' _work/fixture.tl`), which
  pushes and confirms every prepared transaction, leaving nothing staged.
  Driving `new` through `capture` instead leaves exactly one prepared
  transaction, which is what `publish` with no selector then selects —
  the same shape the scratch measurement above showed (`gitboard new`
  printed `prepared refs/gitboard/prepared/...`).

**Gate and ratchets**

The gate is `bin/cosmic --make ci` run from this repository's root, which
is what `.github/workflows/board.yml` runs
(`grep -n 'make ci' .github/workflows/board.yml` -> `63:          bin/cosmic --make ci`),
with no `--min` or `--min-file`. No `.cosmic-coverage` row needs editing:
`grep -n 'gittransport' .cosmic-coverage` prints nothing and exits 1,
while `wc -l .cosmic-coverage` -> `88 .cosmic-coverage`, so the file
exists and simply carries no row for this module — the change adds
covered lines to a file the floor does not track.

## Non-goals

Not the rendered argv itself. Making a pasted command cwd-proof by
rendering `git -C <dir> push ...` is the stronger answer to reading 1
above, but it is a different change: it alters the contract of
`render_argv` at all three of its call sites
(`grep -rn 'render_argv' _work/*.tl` ->
`_work/gitclaim_cli.tl:191`, `_work/gittransport.tl:196`,
`_work/gittransport.tl:245`, plus the declaration at `:17` and the record
entry at `:361`) and the three further hand-rendered commands in
`_work/publish.tl` (lines 87 to 88, 91 to 92, and 181 to 182), several of
which existing tests match on. File it as a sibling; do not fold it in
here.

Not `refresh`. `cmd_refresh` (`_work/gittransport.tl:219`) is equally
silent about the checkout it reconciles, and the same one-line treatment
would fit — but it is a second, independently landable change. Sibling.

Not `--dir`'s resolution rule. `$GITBOARD_DIR` else `.` stays exactly as
it is (`grep -n 'GITBOARD_DIR' _work/gitcommands.tl` ->
`10:  return {long = "dir", arg = "DIR", default = os.getenv("GITBOARD_DIR") or ".",`),
and so does the `bin/gitboard` sibling-probe that sets `GITBOARD_DIR` in
a cosmic checkout.

Not identity validation. Refusing a publish whose resolved checkout does
not match an expected repository has nothing to compare against: a
prepared ref name (`refs/heads/items/<id>`) carries no repository, and
the only per-transaction binding that exists today is the remote NAME on
claim batches and drafts (`grep -n 'bound_remote' _work/gittransport.tl`
-> `134:  if plans[1].bound_remote ~= "" and plans[1].bound_remote ~= remote then`),
never a URL or slug. A refusal would need a
new recorded board identity; that is a separate decision, not this item.

Walls this change must not move: the verdict-line format
`gitboard-<verb>: <detail>` (`_work/gitgate.tl`'s `verdict_line`), the
exit codes publish returns (0 for a render, 2 for an executed push
pending confirmation, 1 for a refusal), the exact `published: <id>` line,
and the rendered push argv itself.

## Access

- cosmic-lua/cosmic — named only inside the evidence transcript above, as
  the wrong repository a hand-run `git push` reached. Nothing in
  `## Change` reads it; the whole diff lands in this item's own repo.
