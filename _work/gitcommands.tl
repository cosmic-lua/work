--- The gitboard CLI's command table: every verb's name, usage line,
--- summary, and flags, in the shape `cosmic.flags` both parses argv
--- and renders help from. Pure declarative data, no dispatch logic of
--- its own — split out of `_work.gitboard`, which sits against the
--- file cap, so a verb's OPTIONS live beside its one-line summary
--- rather than crowding the module that dispatches to it.
local flags = require("cosmic.flags")
local statecommands = require("_work.statecommands")

local function dir_flag(): flags.Flag
  return {long = "dir", arg = "DIR", default = os.getenv("GITBOARD_DIR") or ".",
    help = "state repository checkout (default: $GITBOARD_DIR, else .)"}
end

local PREPARES_ONLY < const > =
"This verb only PREPARES: it composes the final board snapshot and prints\n"
.. "its publication command. The board is unchanged until `gitboard publish\n"
.. "COMMIT` advances and confirms the state branch.\n"
.. "Explicit local mode instead auto-confirms each mutation immediately.\n"
.. "There is no --execute here — claim, renew and drop carry one."

local CSPEC: flags.CommandSpec = {
  name = "gitboard",
  summary = "the work board over committed item files: todo, doing, done\n\n"
  .. "workflow: refresh; claim a set; publish and confirm it; then ordinary\n"
  .. "verbs compose one final snapshot for `gitboard publish COMMIT`. See `help offline`.\n\n"
  .. "ids are KSUIDs; the board renders each item by its handle, the id's last 8 "
  .. "characters\n(e.g. «d0x1_37YJ»), accepted by every verb bare or wrapped, any "
  .. "divider, any case;\nan unambiguous prefix or the full id also work "
  .. "everywhere; each claim's work branch is\nwork/<handle>/<claim>, so "
  .. "expired attempts never collide.",
  commands = {
    {name = "init", summary = "prepare a remote-backed or local-only board",
      spec = {summary = "prepare a state repository. --remote records that "
        .. "caller-fetched remote-tracking refs are authoritative; --local "
        .. "selects the explicit test/migration mode. Without either, mode is "
        .. "inferred from whether a configured Git remote exists.", flags = {dir_flag(),
          {long = "remote", help = "use caller-fetched remote-tracking refs"},
          {long = "remote-name", arg = "NAME", help = "persist the Git remote "
            .. "whose tracking refs are canonical (default: origin)"},
          {long = "local", help = "use local heads (tests and migrations)"},
          {long = "format", arg = "6", help = "fresh board layout (default 6)"}}}},
    {name = "session", summary = "mint an opaque per-run claim identity",
      spec = {usage = "new",
        summary = "mint an opaque per-run claim identity.\n\n"
        .. "The plain output is only the new identity, suitable for "
        .. "`export GITBOARD_SESSION=$(gitboard session new)`. Gitboard "
        .. "does not derive identity from a user, host, provider, or credential."}},
    {name = "claim", summary = "prepare one all-or-nothing two-hour claim set",
      spec = {usage = "ID... [options]",
        summary = "prepare one all-or-nothing two-hour claim set.\n\n"
        .. "Every requested item and current claim is checked before anything is "
        .. "staged. One state commit writes every member's `claims/<id>` file; any overlap rejects the "
        .. "whole set. A direct claim establishes mutual exclusion, without a readiness "
        .. "or shared-capacity gate. A prepared or submitted commit is not authority: "
        .. "only a fetch followed by `gitboard refresh` confirms current authority. "
        .. "Gitboard never discovers or manages credentials.",
        flags = {dir_flag(),
          {long = "session", arg = "ID", help = "minted per-run identity; "
            .. "default $GITBOARD_SESSION"},
          {long = "remote", arg = "NAME",
            help = "Git remote named in rendered/executed push instructions"},
          {long = "repo-dir", arg = "DIR", help = "local product repository "
            .. "override (one-item claims only); otherwise use repository mappings"},
          {long = "fetch-base", help = "when the product repository's local "
            .. "target branch is behind its own configured remote-tracking "
            .. "ref, fetch that remote and fast-forward the branch before "
            .. "capturing the claim base; otherwise such a claim refuses"},
          {long = "execute", help = "explicitly run the exact rendered Git push "
            .. "and fetch argv using caller-configured authentication"}}}},
    {name = "renew", summary = "prepare one all-or-nothing set of fresh two-hour leases",
      spec = {usage = "ID... [options]",
        summary = "prepare one all-or-nothing renewal set for active claims held by this "
        .. "session.\n\nRenewal preserves the initial claim identity and work "
        .. "branch. By default the prepared state publication is printed; "
        .. "--execute opts into publishing and confirming it.",
        flags = {dir_flag(),
          {long = "session", arg = "ID", help = "minted per-run identity; "
            .. "default $GITBOARD_SESSION"},
          {long = "remote", arg = "NAME",
            help = "Git remote named in rendered/executed instructions"},
          {long = "execute", help = "explicitly run the exact rendered Git push "
            .. "and fetch argv using caller-configured authentication"}}}},
    {name = "new", summary = "open an item titled TITLE; role comes from the graph",
      spec = {usage = "TITLE [options]",
        summary = "open an item titled TITLE; role comes from the graph.\n\n"
        .. "Under --parent, a child with neither --before nor --after "
        .. "ranks last among its new\nsiblings (`rank ID --last`'s own "
        .. "motion) — an unranked child can no longer result; the\n"
        .. "verdict line reports where it landed. Outcomes (no --parent) "
        .. "are the one exception\nand stay unranked until positioned.\n\n"
        .. "A `friction:` title is an ordinary item. Put the relevant "
        .. "observations, including\nany language-level findings, in its "
        .. "spec; Gitboard does not infer a roll call from claims.\n\n"
        .. PREPARES_ONLY,
        flags = {dir_flag(),
          {long = "parent", arg = "ID", help = "the item this decomposes; "
            .. "default is the board — the item files as an outcome"},
          {long = "before", arg = "X",
            help = "place it immediately before X among its new siblings"},
          {long = "after", arg = "X",
            help = "place it immediately after X among its new siblings "
            .. "(at most one of --before/--after)"},
          {long = "spec-file", arg = "FILE", help = "spec markdown sidecar"},
          {long = "repo", arg = "OWNER/NAME",
            help = "the repo its PR lands in; default is the board's origin"},
          {long = "touches", arg = "PATH", repeated = true,
            help = "a file this change is expected to touch (repeatable)"},
          {long = "access", arg = "OWNER/NAME", repeated = true,
            help = "a repository this work needs beyond --repo (repeatable)"},
          {long = "session", arg = "SESSION",
            help = "minted holder identity when PARENT is claimed"},
          {long = "force", help = "override a claimed-parent write gate"},
          {long = "why", arg = "REASON", help = "why --force was needed"}}}},
    {name = "attach", summary = "put ID under PARENT (adopt, re-parent)",
      spec = {usage = "ID PARENT [options]",
        summary = "put ID under PARENT (adopt, re-parent).\n\n"
        .. "--before/--after place it among PARENT's other children in the "
        .. "same commit; X\nmust already be one of them, positioned "
        .. "(`rank X --last` first if not).\n\n"
        .. PREPARES_ONLY,
        flags = {dir_flag(),
          {long = "before", arg = "X",
            help = "place it immediately before X among PARENT's children"},
          {long = "after", arg = "X",
            help = "place it immediately after X among PARENT's children "
            .. "(at most one of --before/--after)"},
          {long = "session", arg = "SESSION",
            help = "minted holder identity for claimed items"},
          {long = "force", help = "audited repair of another holder's item"},
          {long = "why", arg = "REASON", help = "why --force was needed"}}}},
    {name = "rank", summary = "position ID among its siblings: before or "
      .. "after X, or last; outcomes rank against outcomes",
      spec = {usage = "ID --before X | --after X | --last [options]",
        summary = "position ID among its siblings: before or after X, or "
        .. "last.\n\nID and X must be siblings — the same parent, or both "
        .. "outcomes (children of the board). X absent from its\nparent's "
        .. "order is refused as unpositioned: rank X first, or use --last.\n\n"
        .. PREPARES_ONLY,
        flags = {dir_flag(),
          {long = "before", arg = "X", help = "place ID immediately before X"},
          {long = "after", arg = "X", help = "place ID immediately after X"},
          {long = "last", help = "place ID last among its siblings"},
          {long = "session", arg = "SESSION",
            help = "minted holder identity for claimed items"},
          {long = "force", help = "audited repair of another holder's item"},
          {long = "why", arg = "REASON", help = "why --force was needed"}}}},
    {name = "set", summary = "repair ID's title, repo, base, touches "
      .. "and/or access (at least one; nothing else moves here)",
      spec = {usage = "ID [options]",
        summary = "repair ID's title, repo, base, touches and/or access "
        .. "(at least one; nothing else moves here).\n\n"
        .. "--touches and --access are repeatable, and each REPLACES its "
        .. "whole list rather than\nappending to it: `set` repairs a field "
        .. "to what the caller states. `depends_on` is not\nhere — it has "
        .. "its own verb, `depend`, because the cycle check belongs in one "
        .. "place.\n\n"
        .. PREPARES_ONLY,
        flags = {dir_flag(),
          {long = "title", arg = "TITLE", help = "the item's title"},
          {long = "repo", arg = "OWNER/NAME",
            help = "the repo its PR lands in; refused on the board — it "
            .. "carries no repo"},
          {long = "base", arg = "BRANCH",
            help = "the branch its PR targets"},
          {long = "touches", arg = "PATH", repeated = true,
            help = "a file this change is expected to touch (repeatable; "
            .. "replaces the list)"},
          {long = "access", arg = "OWNER/NAME", repeated = true,
            help = "a repository this work needs beyond --repo "
            .. "(repeatable; replaces the list)"},
          {long = "session", arg = "SESSION",
            help = "minted holder identity for a claimed item"},
          {long = "force", help = "audited repair of another holder's item"},
          {long = "why", arg = "REASON", help = "why --force was needed"}}}},
    {name = "spec", summary = "replace ID's spec sidecar with FILE",
      spec = {usage = "ID FILE [options]",
        summary = "replace ID's spec sidecar with FILE.\n\n"
        .. PREPARES_ONLY,
        flags = {dir_flag(),
          {long = "base", arg = "FILE",
            help = "the spec text you read, as the compare-and-swap base"},
          {long = "session", arg = "SESSION",
            help = "the session making the write. Omit to derive it from "
            .. "the environment"},
          {long = "force", help = "rewrite another session's LIVE claim's "
            .. "spec (a stale one needs no force)"},
          {long = "why", arg = "REASON", help = "why --force was needed"}}}},
    {name = "depend", summary = "record that ID may not start before ON",
      spec = {usage = "ID ON [options]",
        summary = "record that ID may not start before ON.\n\n"
        .. "Dependency gates whether ID is startable and has no effect on "
        .. "rank: `next` skips ID\nand `take` refuses it while ON is still "
        .. "open. ON's `done` frees it with no further\nverb, and ID stays "
        .. "workable rather than becoming a container. A cycle is refused "
        .. "here,\nnaming the path it would close. See `help depends`.\n\n"
        .. PREPARES_ONLY,
        flags = {dir_flag(),
          {long = "session", arg = "SESSION",
            help = "the session making the write. Omit to derive it from "
            .. "the environment"},
          {long = "force", help = "audited repair of another holder's item"},
          {long = "why", arg = "REASON", help = "why --force was needed"}}}},
    {name = "undepend", summary = "withdraw ID's dependency on ON",
      spec = {usage = "ID ON [options]",
        summary = "withdraw ID's dependency on ON.\n\n"
        .. "A dependency that is already absent is a success that writes "
        .. "nothing. See `help depends`.\n\n"
        .. PREPARES_ONLY,
        flags = {dir_flag(),
          {long = "session", arg = "SESSION",
            help = "the session making the write. Omit to derive it from "
            .. "the environment"},
          {long = "force", help = "audited repair of another holder's item"},
          {long = "why", arg = "REASON", help = "why --force was needed"}}}},
    {name = "next", summary = "the one next action to take now, and what "
      .. "the kind of action means",
      spec = {flags = {dir_flag(),
          {long = "session", arg = "SESSION",
            help = "this session; steps over anything another session "
            .. "has claimed, work and reviews alike. Omit to derive it "
            .. "from the environment (GITBOARD_SESSION, else a runner's "
            .. "own id)"}}}},
    {name = "brief", summary = "print KIND's subagent prompt for ID, "
      .. "board facts filled",
      spec = {usage = "KIND ID [options]",
        summary = "print one role's subagent prompt for ID — KIND is "
        .. "builder, research,\nreview, refine, or decompose — with "
        .. "the item's spec verbatim and every\nboard-known placeholder "
        .. "filled, including the session the item is already\nclaimed "
        .. "under (also named on the closing verdict line) — a review "
        .. "brief\nrefuses when there is none. The verdict\nline names "
        .. "what is still left to fill (a worktree "
        .. "path, a bounce paragraph);\nfill those, then paste the body "
        .. "as the agent's prompt — never\nparaphrase or summarize it, "
        .. "and never hand-write a brief instead: a\nhand-written brief "
        .. "drifts.",
        flags = {dir_flag(),
          {long = "out", arg = "FILE",
            help = "write the filled body to FILE instead of stdout, "
            .. "immune to a channel that decodes escapes"},
          {long = "tree", arg = "DIR",
            help = "measure Teal paths named by ## Change beneath DIR"},
          {long = "receipt", arg = "FILE", help = "validate a v1 builder preparation receipt"},
          {long = "session", arg = "SESSION", help = "receipt caller; default $GITBOARD_SESSION"},
          {long = "gitboard-command", arg = "TEXT",
            help = "the caller's own exact GitBoard invocation (loader plus absolute "
            .. "executable), rendered verbatim as the prefix for every board command "
            .. "the brief prints; requires --gitboard-cwd. A builder brief with "
            .. "--receipt uses the receipt's recorded invocation instead when this "
            .. "is omitted"},
          {long = "gitboard-cwd", arg = "DIR",
            help = "cwd for --gitboard-command; requires --gitboard-command"}}}},
    {name = "worktree", summary = "create ID's builder checkout: branch, "
      .. "worktree, bootstrap, all in one command",
      spec = {usage = "ID [options]",
        summary = "create ID's checkout from its confirmed active claim.\n\n"
        .. "Resolves ID's repo through the explicit repository map (or "
        .. "--repo-dir), creates\nwork/<handle>/<claim-root-short> at the exact "
        .. "recorded claim base, and adds a\nmatching nested worktree beside "
        .. "the checkout. Existing names refuse. Each already-present\n"
        .. "--ref is copied into refs/spike/<basename>. The bootstrap's own "
        .. "fetch/build is quiet by\ndefault, printing only its "
        .. "PASS/FAIL summary line(s) on success and\neverything on a "
        .. "failure; --verbose streams it verbatim instead.\n\n--review "
        .. "starts the same claim branch at the exact handed-over commit. "
        .. "Gitboard performs no Git fetch;\nthe caller must make every named "
        .. "commit and ref locally inspectable first. "
        .. "--verbose applies to either\ncheckout's bootstrap. Pinned cosmic targets use verified cache bytes. "
        .. "--fetch authorizes product acquisition, never board refresh. "
        .. "Local build runs repository code and is not an OS network sandbox.",
        flags = {dir_flag(),
          {long = "repo-dir", arg = "DIR", help = "local product checkout; "
            .. "otherwise use the configured repository mapping"},
          {long = "receipt-out", arg = "FILE", help = "write a v1 builder preparation receipt"},
          {long = "adopt", arg = "DIR", help = "explicitly prepare this exact retained claim checkout; needs --receipt-out"},
          {long = "fetch", help = "allow pinned runtime download on cache miss and product dependency fetch"},
          {long = "gitboard-command", arg = "TEXT", help = "caller-provided invocation, not verified"},
          {long = "gitboard-cwd", arg = "DIR", help = "cwd for the caller-provided invocation"},
          {long = "ref", arg = "REF", repeated = true,
            help = "copy locally prepared REF into refs/spike/<basename> after "
            .. "bootstrap (repeatable)"},
          {long = "review", help = "start at ID's exact handed-over commit "
            .. "instead of its claim base"},
          {long = "verbose", help = "stream the bootstrap's fetch/build "
            .. "output verbatim (a compile/compile-batch line per file) "
            .. "instead of just its PASS/FAIL summary line(s)"},
          {long = "session", arg = "SESSION",
            help = "the claiming session. Omit to derive it from the "
            .. "environment"}}}},
    {name = "take", summary = "record the claimed work's commit handover",
      spec = {usage = "ID --head SHA [options]",
        summary = "record a locally verified product commit as the handover. "
        .. "The commit must descend from the product base recorded by the "
        .. "claim. An optional URL is navigation only; Gitboard performs no "
        .. "provider operation or authenticated network request.\n\n"
        .. PREPARES_ONLY,
        flags = {dir_flag(),
          {long = "session", arg = "SESSION",
            help = "minted claim identity; default $GITBOARD_SESSION"},
          {long = "head", arg = "SHA", help = "product commit handed over"},
          {long = "result", help = "hand over this item's published board state as research evidence"},
          {long = "url", arg = "URL", help = "optional non-authoritative link"},
          {long = "repo-dir", arg = "DIR", help = "local product checkout; "
            .. "otherwise use the configured repository mapping"}}}},
    {name = "drop", summary = "return ID's lease; the item, blockers "
      .. "included, is untouched",
      spec = {usage = "ID [options]",
        summary = "prepare release of the whole-item claim without changing "
        .. "workflow fields. By default Gitboard prints the prepared state "
        .. "publication; --execute publishes and confirms it using ordinary Git "
        .. "with caller-owned authentication.",
        flags = {dir_flag(),
          {long = "why", arg = "REASON",
            help = "why the session lets go (a dead agent, a build out of "
            .. "budget) — worker-side, never the item's gap"},
          {long = "session", arg = "SESSION",
            help = "minted claim identity; default $GITBOARD_SESSION"},
          {long = "remote", arg = "NAME",
            help = "Git remote named in rendered/executed instructions"},
          {long = "execute", help = "run the rendered push and confirmation fetch"},
          {long = "force", help = "drop another session's active claim"}}}},
    {name = "verdict", summary = "record a verdict on one exact commit",
      spec = {usage = "ID KIND --head SHA [options]",
        summary = "record a review verdict whose only evidence is the exact "
        .. "handed-over commit. Gitboard verifies it locally and never reads "
        .. "remote checks or performs a provider write.\n\n"
        .. PREPARES_ONLY,
        flags = {dir_flag(),
          {long = "head", arg = "SHA", help = "the commit judged, which follows "
            .. "the deliverable: the product commit for a diff, the board commit for "
            .. "research"},
          {long = "repo-dir", arg = "DIR", help = "local product checkout; "
            .. "otherwise use the configured repository mapping"},
          {long = "session", arg = "SESSION",
            help = "minted reviewing claim identity; default $GITBOARD_SESSION"},
          {long = "force", help = "record over the distance guard "
            .. "(the session built or specced this item) — repair only"},
          {long = "why", arg = "REASON", help = "why --force was needed"}}}},
    {name = "done", summary = "end ID after locally verifying its landed commit",
      spec = {usage = "ID [options]",
        summary = "end ID after locally verifying its landed commit.\n\n"
        .. PREPARES_ONLY,
        flags = {dir_flag(),
          {long = "reason", arg = "REASON", default = "completed",
            help = "completed or not-planned"},
          {long = "by", arg = "CHILD", help = "an outcome's evidence: its "
            .. "completed child, required with --reason completed"},
          {long = "landed", arg = "SHA", help = "the commit the completed accepted "
            .. "work landed as: the product commit for a diff, the board commit for "
            .. "research"},
          {long = "repo-dir", arg = "DIR", help = "local product checkout; "
            .. "otherwise use the configured repository mapping"},
          {long = "session", arg = "SESSION",
            help = "minted claim identity; default $GITBOARD_SESSION"},
          {long = "force", help = "audited repair past normal completion gates"},
          {long = "why", arg = "REASON", help = "why --force was needed"}}}},
    {name = "handoff", summary = "hand items to a fresh-context reviewer: "
      .. "handoff, checkout and brief",
      spec = {usage = "ID... [options]",
        summary = "hand items to a fresh-context reviewer: handoff, "
        .. "checkout and brief.\n\n"
        .. "Idempotent, in two halves, because a brief needs the handoff "
        .. "CONFIRMED. Items not yet held by --session get ONE handoff "
        .. "batch prepared; publish and refresh it, then run the same "
        .. "command again to get each item's checkout and filled brief. "
        .. "Omit --session and one is minted and printed for the second "
        .. "call.",
        flags = {dir_flag(),
          {long = "session", arg = "SESSION",
            help = "the REVIEWER identity; omit to mint one"},
          {long = "out", arg = "FILE",
            help = "write briefs here; a directory when several ids are named"},
          {long = "tree", arg = "DIR", help = "passed to `brief --tree`"},
          {long = "no-worktree",
            help = "skip the checkouts; briefs only"},
          {long = "fetch", help = "passed to `worktree --fetch`"},
          {long = "remote", arg = "NAME", help = "the board remote"},
          {long = "gitboard-command", arg = "TEXT",
            help = "the caller's own gitboard invocation, for the brief"},
          {long = "gitboard-cwd", arg = "DIR",
            help = "cwd for --gitboard-command"}}}},
    {name = "show", summary = "the board (no ID), or one item: fields, "
      .. "spec-bar problems, spec, git history",
      spec = {usage = "[ID] [options]",
        summary = "the board (no ID), or one item: fields, spec-bar "
        .. "problems, spec, git history.\n\n"
        .. "Bare `show` renders the top of todo, 8 rows by default; "
        .. "`--todo 0` renders every todo row at once. `--summary` "
        .. "replaces the rows with counts by repository. No effect "
        .. "with an ID.",
        flags = {dir_flag(),
          {long = "todo", arg = "N",
            help = "how many todo rows to show (0 = all; default 8); "
            .. "no effect with an ID"},
          {long = "summary",
            help = "counts by state and repository instead of rows; "
            .. "no effect with an ID"},
          {long = "raw", help = "print an ID's spec sidecar byte-exactly"}}}},
    {name = "log", summary = "one item's own commit history: every entry its "
      .. "mutations recorded",
      spec = {usage = "ID [options]",
        summary = "one item's own commit history, newest first.\n\n"
        .. "Each entry prints when it happened, who made it, and the "
        .. "mutation's subject,\nfollowed by that commit's message body "
        .. "indented — the retrospective record: what\nwas measured, what "
        .. "was found, what happened along the way. A commit carrying no "
        .. "body\nprints its subject alone. --oneline keeps the subjects "
        .. "and drops every body.\n\n"
        .. "--add FILE appends FILE as one entry, and is the only way in: "
        .. "the commit it\nwrites carries the prose and nothing else — no "
        .. "field, no spec, no rank moves — so an\nobservation needs no "
        .. "other mutation to ride along with. An entry is immutable; a\n"
        .. "correction is another entry. An item under another session's "
        .. "live claim is\nthe holder's to append to: a foreign --add "
        .. "needs --force --why, like every other\nmutation of a claimed "
        .. "item.\n\n"
        .. "With --add, " .. PREPARES_ONLY,
        flags = {dir_flag(),
          {long = "oneline", help = "subjects only, one line per entry"},
          {long = "add", arg = "FILE",
            help = "append FILE as one entry, leaving the item unchanged"},
          {long = "session", arg = "ID", help = "minted identity the entry "
            .. "is attributed to; default $GITBOARD_SESSION"},
          {long = "force", help = "append past another session's live claim "
            .. "— audited repair only"},
          {long = "why", arg = "REASON", help = "why --force was needed"}}}},
    {name = "snapshot", summary = "inspect, summarize, or abandon the local composition",
      spec = {usage = "[--check | --summary TEXT | --abandon COMMIT] [options]",
        summary = "inspect the one clone-local final-board composition. Set its final human "
        .. "summary before publication, or abandon it only when unpublished or after a "
        .. "proven conflict (the commit remains retained for recovery).",
        flags = {dir_flag(),
          {long = "check", help = "validate and preflight the final board"},
          {long = "summary", arg = "TEXT", help = "replace the final commit summary"},
          {long = "abandon", arg = "COMMIT", help = "retain and clear this conflicted snapshot"}}}},
    {name = "publish", summary = "publish and confirm one final board snapshot",
      spec = {usage = "COMMIT [options]",
        summary = "publish one full snapshot commit against its exact canonical parent, "
        .. "fetch the destination, and confirm its complete identity. Shell Git owns "
        .. "authentication. A conflict never rebases or replays the snapshot. A Work "
        .. "session uses the internal protocol actions to perform the connector calls.",
        flags = {dir_flag(),
          {long = "remote", arg = "NAME",
            help = "Git remote named in the push argv"},
          {long = "head", arg = "SHA", help = "protocol update: destination head observed immediately before the call"},
          {long = "protocol", arg = "ACTION", help = "internal Work snapshot protocol action"},
          {long = "returned-tree", arg = "SHA", help = "internal Work tree result"},
          {long = "candidate", arg = "SHA", help = "internal Work commit result"}}}},
    {name = "refresh", summary = "inspect fetched refs; claims gain authority only here",
      spec = {summary = "confirm snapshot publication and claim authority from caller-fetched "
        .. "remote-tracking refs, then rebuild\nthe disposable cache. Without "
        .. "--execute, inspects the refs already fetched by the caller.\n"
        .. "--execute fetches the configured publication destination before confirmation; "
        .. "credentials remain caller-owned. Exit 2 means publication remains "
        .. "unconfirmed; a lost lease exits 1.",
        flags = {dir_flag(),
          {long = "remote", arg = "NAME",
            help = "Git remote and remote-tracking namespace to inspect"},
          {long = "execute", help = "fetch the publication destination before inspection"}}}},
    {name = "sync", summary = "deprecated alias for local-only refresh",
      spec = {summary = "deprecated: use refresh. This compatibility alias never "
        .. "fetches or performs provider operations.", flags = {dir_flag()}}},
    {name = "fsck", summary = "read-only board audit: edges, trees, keys, flags",
      spec = {flags = {dir_flag()}}},
    {name = "find", summary = "full-text search over titles and specs, "
      .. "ranked, a snippet per hit",
      spec = {usage = "TEXT... [options]", flags = {dir_flag()}}},
  },
}
statecommands.extend(CSPEC)
local record gitcommands
  CSPEC: flags.CommandSpec
end

local M: gitcommands = {
  CSPEC = CSPEC,
}

return M
