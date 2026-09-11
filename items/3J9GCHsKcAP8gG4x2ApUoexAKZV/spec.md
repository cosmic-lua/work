## Evidence

`gitboard brief review ID`'s rendered body names a worktree path the
tool never actually creates. Reproduced twice on 2026-09-10 (items
`jqgp_Bzmp` and `UqZn_jV6U`, both `cosmic-lua/cosmic`): the brief said

```
Do this from your own fresh checkout at `/home/user/wt/review-<full-id>` — never reuse
another agent's worktree.
```

and repeated that same fabricated path in three `gitboard verdict`/`take`
example command lines further down. Neither path exists — the real
worktree, created moments earlier by `gitboard worktree ID --review
...`, is at `/home/user/wt/work/<handle>/<claim-short>` (the same
`work/<handle>/<claim>` shape every other worktree in this session
used, builder and reviewer alike). A reviewing agent given the brief
verbatim, per its own instruction to follow it exactly, would try to
`cd` into a directory that was never created.

One affected agent burned ~3 tool calls (~a few minutes) discovering
the mismatch by listing `/home/user/wt/work/` and checking branches
directly, after the environment's own "primary working directory"
system line pointed at a THIRD, also-wrong path (a sibling item's
worktree on an unrelated branch) — three different, mutually
inconsistent worktree pointers in one task. For the second occurrence,
the orchestrator caught it by grepping the rendered brief before
spawning and corrected it in the spawn prompt, but that is a manual
workaround, not something `brief review` should require every time.

## Change

`_work/brief.tl` invents the `<WORKTREE>` path from the item id
instead of deriving the one `_work/gitworktree.tl` actually builds.
Delete the invention; derive the path the same way `worktree` does,
through one helper both modules call, so the two cannot drift again.

Everything below was measured in `cosmic-lua/work` at `098d7ca1`
(`git rev-parse --short HEAD`) unless the command says otherwise.
That repo has no `AGENTS.md`; its gate is `bin/cosmic --make ci` and
its file-length ceiling is cosmic's 500 lines, so each file's current
count is given.

### The defect, reproduced

From `/home/user/cosmic`, against board item `«eXY3_wPY6»` (state
`review`, repo `cosmic-lua/work`, a live claim and a handover head):

```
$ bin/gitboard brief review eXY3wPY6 | grep -n 'fresh checkout at'
248:Do this from your own fresh checkout at `/home/user/wt/review-3J919Qef` — never reuse
$ ls -d /home/user/wt/review-3J919Qef /home/user/wt/work/eXY3wPY6/*
ls: cannot access '/home/user/wt/review-3J919Qef': No such file or directory
/home/user/wt/work/eXY3wPY6/1c9b4c293e24
/home/user/wt/work/eXY3wPY6/7b0b5ede2828
```

The two directories that DO exist are what `worktree` makes.
`bin/gitboard help worktree` states the shape:

```
Resolves ID's repo through the explicit repository map (or --root), creates
work/<handle>/<claim-root-short> at the exact recorded claim base, and adds a
matching nested worktree beside the checkout.
```

In source that is `_work/gitworktree.tl:249-250` (review) and
`:339-340` (builder), both:

```
  local branch = claim.branch(it.id, st.root)
  local path = fs.join(fs.dirname(checkout), "wt", branch)
```

where `checkout` came from `repository_map.resolve(s.root, repo,
root_override)` and `st` from the item's claim batch. `claim.branch`
(`_work/claim.tl:123`) is `("work/%s/%s"):format(item_id:sub(-8),
root:sub(1, 12))`.

`_work/brief.tl:375-387` instead builds its path from
`product_root()` and the id's FIRST eight characters, which is neither
directory:

```
    local id8 = it.id:sub(1, 8)
    local wt = fs.join(fs.dirname(root), "wt", id8)
    if kind == "builder" and fs.is_dir(wt) then
      values["WORKTREE"] = wt
    elseif kind == "review" and template:find("<WORKTREE>", 1, true) ~= nil then
      values["WORKTREE"] = fs.join(fs.dirname(root), "wt", "review-" .. id8)
    end
```

The builder arm is the same invention with a different suffix; it is
merely harmless today because `fs.is_dir` never matches it, so
`<WORKTREE>` survives unfilled and the verdict line reports it owed.
The review arm has no such guard, which is the reported bug. Both
arms are replaced, because they are one block and leaving one behind
leaves two competing derivations inside it.

`_work/doctrine.tl:309-311` already claims the behaviour this change
produces — "`worktree`'s own verdict line names the path; `brief
builder ID` reads the same path back into its 'Where to work' section
without it being retyped" — so no prose there moves; the code catches
up to it.

### The sweep

Every site carrying either fabricated shape:

```
$ grep -rn 'wt", "review-\|wt/review-\|wt", id8' _work
_work/brieftext_review.tl:16:--- `<root>/../wt/review-<id8>`, filled for the reviewer-created fresh
_work/gitworktree_review_test.tl:198:  local expect = fs.join(fs.dirname(checkout), "wt", "review-" .. id8)
_work/gitworktree_review_test.tl:215:  local expect = fs.join(fs.dirname(checkout), "wt", "review-" .. id8)
_work/gitworktree_test.tl:374:  local expect = fs.join(fs.dirname(checkout), "wt", id8)
_work/brief_rework_test.tl:162:  local wt = fs.join(fs.dirname(WT_ROOT), "wt", id8)
_work/brief_rework_test.tl:202:  local expect = fs.join(fs.dirname(WT_ROOT), "wt", "review-" .. id8)
_work/brief.tl:382:    local wt = fs.join(fs.dirname(root), "wt", id8)
_work/brief.tl:386:      values["WORKTREE"] = fs.join(fs.dirname(root), "wt", "review-" .. id8)
```

All eight are edited below, and that same grep prints nothing when
the change is done.

### 1. `_work/claim.tl` (154 lines) — the one derivation

Add `local fs = require("cosmic.fs")` to the requires (the module
currently requires only `_work.identity`) and, beside `branch`, a
two-argument path builder:

```teal
--- The worktree path a claim's branch takes: the `wt` directory beside
--- the product checkout, then the branch name.
--- @param checkout string The local product checkout
--- @param branch string The claim's branch, from `branch` above
--- @return string The worktree path
local function worktree(checkout: string, branch: string): string
  return fs.join(fs.dirname(checkout), "wt", branch)
end
```

Add `worktree` to the `claim` record and to `M`. `fs.join` and
`fs.dirname` are pure path functions, so the module stays free of
transport and storage.

### 2. `_work/gitworktree.tl` (404 lines) — call it

At `:250` and `:340`, replace

```
  local path = fs.join(fs.dirname(checkout), "wt", branch)
```

with

```
  local path = claim.worktree(checkout, branch)
```

Both sites already hold `branch` from `claim.branch(...)` and already
require `_work.claim`; nothing else in either function moves.

### 3. `_work/brief.tl` (472 lines, 28 under the cap) — derive, don't invent

Add `local claim = require("_work.claim")` and `local claimbatch =
require("_work.claimbatch")` to the requires. `_work.repository_map`
is already required (`:35`) and already used the same way at `:137`.

Add a file-local helper beside `product_root`:

```teal
--- The checkout `worktree ID` makes for this item's claim: the same
--- `<checkout>/../wt/work/<handle>/<claim-root-short>` path
--- `_work.gitworktree` builds, from the same repository map and the
--- same claim batch. "" when the item has no claim batch, its batch no
--- longer holds a claim, or no local checkout is mapped for its repo —
--- the board cannot answer the placeholder in any of those cases.
--- @param s store.Store The store
--- @param it item.Item The item under brief
--- @return string The worktree path, "" when it cannot be derived
local function worktree_path(s: store.Store, it: item.Item): string
  local pointer = it.claim_batch or ""
  if pointer == "" then return "" end
  local st, _serr = claimbatch.read_state(s.root, pointer, it.id)
  if st == nil then return "" end
  local checkout, _cerr = repository_map.resolve(s.root, it.repo or "", "")
  if checkout == nil then return "" end
  return claim.worktree(checkout, claim.branch(it.id, st.root))
end
```

`claimbatch.read_state` returns `nil, ""` for a dropped claim and
`nil, err` for an unreadable batch (`_work/claimbatch.tl:233-241`);
both are the same "" answer here. It reads local git objects only — no
network, no provider call, no lease-liveness requirement, so an
EXPIRED claim still names its own worktree.

Then delete `:375-387` — the whole quoted block above, comment
included — leaving `if root ~= "" then values["PRODUCT_ROOT"] = root
end` (`:373-374`, `:388`), and put the fill in its own statement after
that `end`, no longer gated on `product_root()` resolving:

```teal
  -- `<WORKTREE>`: `worktree ID` (or `worktree ID --review`) already made
  -- the checkout at exactly this path, so a brief fills it only once
  -- that directory exists on disk — the same "unfilled until the board
  -- can answer it" rule every other placeholder follows. `REVIEW_SCRIPT`
  -- carries no `<WORKTREE>`, so the work is skipped for it.
  if kind == "builder" or (kind == "review"
    and template:find("<WORKTREE>", 1, true) ~= nil) then
    local wt = worktree_path(s, it)
    if wt ~= "" and fs.is_dir(wt) then
      values["WORKTREE"] = wt
    end
  end
```

Builder and review now follow ONE rule: fill with the path `worktree`
built, or leave the placeholder for the verdict line to report. Net
effect on the file is about +10 lines (482 of 500).

### 4. `_work/brieftext_review.tl` (240 lines) — the stale docstring

Lines 15-17 state the fabricated derivation:

```
--- `<WORKTREE>` in `REVIEW` is `_work.brief`'s own
--- `<root>/../wt/review-<id8>`, filled for the reviewer-created fresh
--- checkout. `REVIEW_SCRIPT` is checkout-free: ...
```

Replace the first sentence with the real one: `<WORKTREE>` in `REVIEW`
is the review checkout `worktree ID --review` makes — the `wt`
directory beside the mapped product checkout, then the claim's own
`work/<handle>/<claim-root-short>` branch — filled only once that
directory exists. Leave the `REVIEW_SCRIPT` sentence after it intact.

The template TEXT does not change. `_work/brieftext_test.tl:211`
asserts `REVIEW:find("fresh checkout") ~= nil` and `:213` asserts it
still contains `<WORKTREE>`; both must keep passing untouched.

### 5. `_work/brief_rework_test.tl` (245 lines) — the regression tests

This file already owns the `<WORKTREE>` fill tests (its header says
so). Its `handover_item` (`:73`) writes bare metadata — no claim
batch, no repository mapping — so `worktree_path` would return "" for
every test here. Give it both.

Add a `claimed_item(s, leaf): string` helper that copies the pattern
already working in `_work/brief_review_script_test.tl:104-137`
(`handover_diff`): create a product checkout under `TEST_TMPDIR`, `git
init -q` it with a `user.name`/`user.email` and one commit (so
`repository_map.validate`'s `rev-parse --show-toplevel` and
`--show-prefix` both succeed), map it in the board checkout with
`fixture.git(s.root, {"config", "--local", "--add",
"gitboard.repository", "acme/widgets=" .. checkout})`, prepare a real
claim batch for `leaf` held by `session-a` via
`gitclaim.prepare_batch` + `prepared.promote_local`, set `it.repo =
"acme/widgets"`, and return the checkout path. Have `handover_item`
call it and keep setting `it.handover_head = HEAD` (the fake 40-`b`
SHA) afterwards.

Keeping `handover_head` fake matters: `local_mechanical_diff`
(`_work/brief.tl:134`) now CAN resolve the mapping, runs `git diff
BASE HEAD` in the fixture checkout, fails on the unknown SHAs and
returns false — so the full `REVIEW` template, the one carrying
`<WORKTREE>`, is still the one selected. A real base/head pair could
flip these tests to `REVIEW_SCRIPT`, which has no placeholder at all.

Compute the expected path in the tests exactly as
`_work/gitworktree_review_test.tl:154-158`'s `branch_of` does — load
the item, `claimbatch.read_state(s.root, it.claim_batch, leaf)`, then
`claim.worktree(checkout, claim.branch(leaf, st.root))`.

Then:

- Rewrite `test_review_brief_names_its_own_worktree_path_unconditionally`
  (`:197`, and its comment at `:194-196`) into a case that creates the
  derived directory with `fs.make_dirs`, renders the review brief, and
  asserts the body contains it and no longer contains `<WORKTREE>`.
  Its current `expect` (`:202`) is the fabricated path and must go,
  and the "unconditionally" in its name is no longer true.
- Add a sibling case that does NOT create the directory and asserts
  `<WORKTREE>` survives and the closing verdict line names it — the
  same pair `test_builder_brief_leaves_worktree_unfilled_before_worktree_id_runs`
  (`:178`) already makes for builders.
- `test_builder_brief_fills_worktree_once_it_exists` (`:157`)
  hand-makes `fs.join(fs.dirname(WT_ROOT), "wt", id8)` at `:162`. Its
  item has no repo and no claim at all, so give it `claimed_item` too
  (no handover head) and make the derived directory instead.
- `test_review_brief_preserves_literal_template_tokens_in_spec`
  (`:227`, the file's last test) asserts the closing line says
  `nothing left to fill`. Under the new rule `<WORKTREE>` is a
  survivor unless the directory exists, so this test must create the
  derived directory as well or it flips to a failure. This is the trap
  in this change; fix it in the same diff.
- `test_builder_rework_brief_uses_only_the_judged_commit` (`:98`) and
  `test_product_root_falls_back_to_cwd_when_the_guess_is_wrong`
  (`:124`) assert nothing about `<WORKTREE>` and need no edit beyond
  whatever `handover_item` now does for them.

### 6. The three vacuous refusal assertions

`_work/gitworktree_review_test.tl:198` and `:215`, and
`_work/gitworktree_test.tl:374`, each build a fabricated `expect` and
then assert `not fs.is_dir(expect)` — an assertion that passes
whatever the verb does, because no scheme ever creates those names. In
all three, replace the `local expect = ...` line with the `wt` root
itself:

```teal
  local expect = fs.join(fs.dirname(checkout), "wt")
```

so the assertion means "the refusal happened before any worktree
directory was made anywhere". All three refusals are reached inside
`cmd_worktree` before `fs.make_dirs` runs (`active_claim` at
`_work/gitworktree.tl:322` refuses an item with no `claim` or no
`claim_batch`, which is what each fixture builds), so the `wt`
directory genuinely does not exist.

Drop the now-unused `local id8 = leaf:sub(1, 8)` in the two
`_work/gitworktree_review_test.tl` cases — `id8` has no other use in
either. KEEP it in `_work/gitworktree_test.tl`, where the same
function reads it again at `:391` for the `refs/heads/<id8>` check;
that check stays as it is (see Non-goals).

## Non-goals

- Not about the environment-line mismatch (a separate, harness-level
  issue outside gitboard) — only about `brief`'s own template naming a
  path it does not create.
- The `REVIEW` template's prose is unchanged. `_work/brieftext_test.tl`
  asserts `REVIEW` still contains `fresh checkout` (`:211`) and
  `<WORKTREE>` (`:213`), and that `REVIEW_SCRIPT` contains neither
  (`:199`, `:206`) and stays checkout-free. Those four assertions are
  a wall: they must pass untouched.
- Preparation receipts stay builders-only.
  `_work/preparation_receipt.tl:137` refuses `--receipt-out` with
  `--review` (`"--receipt-out supports builders only"`) and
  `_work/gitworktree.tl:306` refuses `--adopt` with it; teaching
  reviews to write a receipt (so `prep.worktree` could answer directly)
  is a larger change and not this one.
- `_work/gitworktree_test.tl:391-393`'s `refs/heads/<id8>` assertion is
  vacuous in the same way as the path assertions beside it, but
  asserting the real branch name needs a claim root the unclaimed
  fixture does not have. Leave it; it is its own item if anyone wants it.
- `worktree --review` itself is correct and does not move. Nothing in
  `_work/gitworktree.tl` changes except the two `path` expressions.
- No new verb, flag, or item field — `_work/gitcommands.tl`,
  `_work/gitboard.tl` and `_work/gitverbs.tl` are untouched.

The guard this diff adds lives in `_work/brief_rework_test.tl`; the
two it repairs live in `_work/gitworktree_review_test.tl` and
`_work/gitworktree_test.tl`. Run one with `bin/cosmic --make test
_work/<file>`.
