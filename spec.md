# pin: bump bin/gitboard.pin to a release that understands format 5

## Change

Depends on `03-verbs` AND on `05-migration`'s CODE having merged: the release
this pins must carry `02-tree-and-fields`, `03-verbs` and the `migrate` verb,
because no clone can read or write a format-5 board until its pinned build
understands one, and the migration run cannot happen until every session's
`bin/gitboard` is a build that carries the verb. The ordering was reversed
after a measurement: release `2026-09-13-44281f4` (the chain through
`03-verbs`, without `migrate`) answers the live board with
`refs/heads/board/format is 4, this tool expects 5 — run `gitboard migrate`
before reading or writing the board`, so pinning it would have darkened the
board for the whole item cycle `05-migration`'s code takes. Pinning the
release that carries the verb instead narrows the dark window to the minutes
between this merging and the migration's push, which the orchestrator runs
from this pin in the same sitting.

This item's `repo` is **cosmic-lua/cosmic**, not cosmic-lua/work: the pin is a
file on cosmic's `main`. The machinery repository has no copy of it —

```
$ ls /path/to/work/bin
cosmic  cosmic.pin
$ ls /path/to/cosmic/bin
cosmic  cosmic.pin  gitboard  gitboard.pin
```

The release itself needs no change: every push to cosmic-lua/work's `main`
already publishes one, tagged `YYYY-MM-DD-<sha7>`, with the binary and its
sha256 in `SHA256SUMS`
(`.github/workflows/release.yml:45`, `echo "tag=$(date -u +%Y-%m-%d)-${GITHUB_SHA::7}" >> "$GITHUB_OUTPUT"`,
and `:78`, `(cd release && sha256sum gitboard > SHA256SUMS && cat SHA256SUMS)`).
So the whole change is two lines.

### `bin/gitboard.pin` in cosmic-lua/cosmic

The file is two data lines under a comment header, read with `sed` and nothing
else:

```
$ cat bin/gitboard.pin
# The board's one pin: the gitboard release bin/gitboard runs.
#
# Read by bin/gitboard with sed, so it stays two plain lines like
# bin/cosmic.pin. Every push to main of cosmic-lua/work publishes a
# release; bump both fields together, the sha is what is verified
# before anything is executed.
url = https://github.com/cosmic-lua/work/releases/download/2026-09-12-b9d6a96/gitboard
sha256 = b1833c18adbb791d27dc69eb1df3ece7c0d8ad555d6b207831d73aa3cfcc0fd8
```

Replace the tag in `url` with the release cut from the cosmic-lua/work commit
that merged `05-migration`'s code (the newest release at the time of the
bump; `03-verbs` is already behind it), and `sha256` with that release's own
`SHA256SUMS` value.
Both lines move together; the comment header is unchanged. Nothing else in
cosmic's tree names the pin's contents:

```
$ grep -rn "gitboard.pin" --include='*.md' --include='gitboard' --include='*.tl' . \
    | grep -v '^./o/'
./skills/work/SKILL.md:30:trust root `bin/gitboard` (`bin/gitboard.pin` names it), so nothing
./AGENTS.md:469:`bin/gitboard` runs (`bin/gitboard.pin`).
./_build/gitboard_pin_test.tl:8:local PIN < const > = "bin/gitboard.pin"
./_build/gitboard_pin_test.tl:36:  assert(text:find("gitboard.pin", 1, true), "bin/gitboard does not name its pin")
./bin/gitboard:5:# smaller. Obtain the ONE pinned artifact named in bin/gitboard.pin — a
./bin/gitboard:25:PIN="${SCRIPT_DIR}/gitboard.pin"
./_cli/gitboard_root_test.tl:22:  assert(fs.write(fs.join(root, "bin", "gitboard.pin"),
```

The one gate over the pin is `_build/gitboard_pin_test.tl` (38 lines): it checks
the SHAPE, not the value — `_build/gitboard_pin_test.tl:28`
(`assert(f.url:sub(1, #RELEASES) == RELEASES, "url is not a cosmic-lua/work release: " .. f.url)`)
and `:30` (`assert(#f.sha256 == 64 and f.sha256:match("^%x+$"),`) — so a
correct bump needs no test edit and a malformed one fails `--make ci`. Do not
loosen it to accept the new tag; the tag is not what it reads.

`bin/gitboard` (169 lines) reads the two fields at `bin/gitboard:62`
(`url="$(sed -n 's/^url *= *//p' "${PIN}")"`) and `:63`, verifies the sha at
`:76` (`if ! verify_sha256 "${boot_tmp}" "${sha256}"; then`), and caches the
verified binary against that sha at `:69`
(`[ "$(cat "${BOOTSTRAP}.pin" 2>/dev/null)" = "${sha256}" ]`), so every clone
re-downloads on the next invocation with no other step. **No edit to
`bin/gitboard` itself.**

### What the bump does to a session, and what to say about it

Between this merging and `05-migration` completing, the live board is
unoperable by design: `02-tree-and-fields` set `format.CURRENT` to `"5"` while
`refs/heads/board/format` still reads `4`
(`git cat-file -p refs/remotes/origin/board/format:format` prints `4`), and
`format.refusal` answers a format-4 board with
`run `gitboard migrate` before reading or writing the board`. So this item and
`05-migration`'s run land back to back, and the migration is run by the same
build this pin names — not by a checkout of the machinery tree, which would be
a second build.

Verify the pin the way the trust root does, and paste the output in the PR:

```
$ rm -rf o/bootstrap && bin/gitboard help | head -1
$ o/bootstrap/gitboard help | grep -c "depend"   # the verbs 03-verbs added
$ o/bootstrap/gitboard help | grep -c "migrate"  # the verb 05-migration added
```

## Non-goals

- No change to `bin/gitboard`, to cosmic's `bin/cosmic.pin`, or to any workflow
  in either repository. The release mechanism already produces what this pins.
- The migration is not run here. This item ends with a pin that can run it;
  `05-migration`'s run, from this pin, is the next thing that happens.
- No change to cosmic's `skills/work/SKILL.md`. The skill points at the tool
  and restates none of its verbs, so the two new verbs reach every session
  through this pin alone.

## Access

- cosmic-lua/work — the release this pins is published there
  (`https://github.com/cosmic-lua/work/releases`), its tag and `SHA256SUMS` are
  what the two lines carry, and `03-verbs` (the item this depends on) is a
  change to that repository.
