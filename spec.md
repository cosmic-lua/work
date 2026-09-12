## Evidence

`gitboard brief review` picks between a full adversarial review and a
short four-move "mechanical" script. The predicate it prints is:

    This diff is mechanical: no changed `.tl` file outside `*_test.tl`,
    or fewer than 20 changed lines in total.

Both halves are stated in Teal terms, so the first is **vacuously true
for any diff containing no Teal at all**. A change of any size in C, Lua,
Markdown, or a workflow file is therefore classified mechanical.

Observed on `«kcoY_pv9c»` (cosmic-lua/cosmopolitan, PR #396), a change to
the `Fetch` binding's proxy resolution:

    $ git diff --stat HEAD~1..HEAD
     tool/lua/test_fetch_local.lua |   7 +-
     tool/lua/test_fetch_proxy.lua | 198 +++++++++++++++++-
     tool/net/definitions.lua      |  16 +++-
     tool/net/fetch.inc            |  53 ++++++++-
     tool/net/lfetch.c             |  19 +++-
     5 files changed, 281 insertions(+), 12 deletions(-)

281 changed lines across a C include shared by two binaries, a C file,
and the binding-contract source of truth — and the brief handed its
reviewer the script reserved for a sub-20-line diff.

The consequence is worst exactly where it is most likely to fire.
cosmic-lua/cosmopolitan contains no Teal by construction, so EVERY review
of that repository is mechanical, no matter how large, including changes
to the `cosmo.*` binding contracts that cosmic's generated types and
wrappers depend on. The same holds for any `docs/**`-only or
`.github/workflows/**`-only change in either repo.

The mechanical script is not a lighter version of the full one: it drops
the "judge the diff against the item's parent chain", "the walls held",
"it is the least thing" and conventions moves entirely, replacing them
with four fixed steps. A reviewer following it as written does not
examine scope creep or Non-goals at all.

Caught by hand this session before the review ran; the reviewer was given
a full-review instruction instead.

## Change

Express the mechanical test in terms that hold for every repository the
board serves, not only Teal ones. A diff is mechanical when it is small
by a measure that does not assume a language — changed-line count is
already half the predicate and is language-agnostic — and when nothing it
touches is a source file the repo treats as product code.

Where the test needs to know what "product code" means for a repository,
resolve that the way the briefs already resolve repo mechanics, rather
than hard-coding a second list of extensions.

Add cases: a large diff in a repository with no Teal is NOT mechanical; a
genuinely small diff still is, in both a Teal and a non-Teal repository;
and a large diff touching only `*_test.tl` keeps whatever answer it has
today.

## Non-goals

Not changing either review script's text, not changing what a reviewer is
asked to do once a kind is chosen, and not adding a third kind. Not
changing the 20-line threshold itself. Not touching the `<PRODUCT_ROOT>`
resolution `«WsH8_pWpE»` fixed — that is landed and separate, though it
is the same brief.

## Access

cosmic-lua/work, read and write on a branch; no other repository.
