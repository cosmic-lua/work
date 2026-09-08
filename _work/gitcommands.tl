--- The gitboard CLI's command table: every verb's name, usage line,
--- summary, and flags, in the shape `cosmic.flags` both parses argv
--- and renders help from. Pure declarative data, no dispatch logic of
--- its own — split out of `_work.gitboard`, which sits against the
--- file cap, so a verb's OPTIONS live beside its one-line summary
--- rather than crowding the module that dispatches to it.
local flags = require("cosmic.flags")

local function dir_flag(): flags.Flag
  return {long = "dir", arg = "DIR", default = os.getenv("GITBOARD_DIR") or ".",
    help = "state repository checkout (default: $GITBOARD_DIR, else .)"}
end

local CSPEC: flags.CommandSpec = {
  name = "gitboard",
  summary = "the work board over committed item files: todo, doing, done\n\n"
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
          {long = "local", help = "use local heads (tests and migrations)"}}}},
    {name = "session", summary = "mint an opaque per-run claim identity",
      spec = {usage = "new",
        summary = "mint an opaque per-run claim identity.\n\n"
        .. "The plain output is only the new identity, suitable for "
        .. "`export GITBOARD_SESSION=$(gitboard session new)`. Gitboard "
        .. "does not derive identity from a user, host, provider, or credential."}},
    {name = "migrate", summary = "prepare the one-hop board format migration",
      spec = {summary = "advance only the board format marker; existing item "
        .. "commits remain byte-for-byte unchanged. Remote boards print exact "
        .. "leased push/fetch instructions by default. --execute runs those "
        .. "ordinary Git commands with caller-owned authentication.",
        flags = {dir_flag(),
          {long = "remote", arg = "NAME",
            help = "Git remote named in rendered/executed instructions"},
          {long = "execute", help = "run the rendered push and confirmation fetch"}}}},
    {name = "claim", summary = "prepare independent two-hour claims for IDs",
      spec = {usage = "ID... [options]",
        summary = "prepare independent two-hour claims for IDs.\n\n"
        .. "Each item is a separate leased ref update, so overlapping callers "
        .. "may win different\nsubsets and can never both win one item. By "
        .. "default this prints the exact ordinary\nGit push commands and "
        .. "performs no network operation. --execute runs those same commands "
        .. "with\nthe caller's Git configuration; gitboard never discovers or "
        .. "manages credentials.",
        flags = {dir_flag(),
          {long = "session", arg = "ID", help = "minted per-run identity; "
            .. "default $GITBOARD_SESSION"},
          {long = "remote", arg = "NAME",
            help = "Git remote named in rendered/executed push instructions"},
          {long = "repo-dir", arg = "DIR", help = "local product repository "
            .. "override (one-item claims only); otherwise use repository mappings"},
          {long = "force", help = "take over an unexpired foreign claim"},
          {long = "why", arg = "REASON", help = "audited reason required with --force"},
          {long = "execute", help = "explicitly run the exact rendered Git push "
            .. "and fetch argv using caller-configured authentication"}}}},
    {name = "renew", summary = "prepare fresh two-hour leases for owned IDs",
      spec = {usage = "ID... [options]",
        summary = "prepare independent renewals for active claims held by this "
        .. "session.\n\nRenewal preserves the initial claim identity and work "
        .. "branch. By default only exact\nleased Git instructions are printed; "
        .. "--execute opts into running them.",
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
        .. "A `friction:` title is refused unless its spec (--spec-file) "
        .. "names every agent this\nsession claimed work under since the "
        .. "pass began, one `## <kind> <handle>` heading\neach; "
        .. "--force --why files it anyway (a pass whose transcripts are "
        .. "gone).",
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
          {long = "session", arg = "SESSION",
            help = "minted holder identity when PARENT is claimed"},
          {long = "force", help = "file a `friction:` item over an "
            .. "incomplete roll call"},
          {long = "why", arg = "REASON", help = "why --force was needed"}}}},
    {name = "attach", summary = "put ID under PARENT (adopt, re-parent)",
      spec = {usage = "ID PARENT [options]",
        summary = "put ID under PARENT (adopt, re-parent).\n\n"
        .. "--before/--after place it among PARENT's other children in the "
        .. "same commit; X\nmust already be one of them, positioned "
        .. "(`rank X --last` first if not).",
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
        .. "order is refused as unpositioned: rank X first, or use --last.",
        flags = {dir_flag(),
          {long = "before", arg = "X", help = "place ID immediately before X"},
          {long = "after", arg = "X", help = "place ID immediately after X"},
          {long = "last", help = "place ID last among its siblings"},
          {long = "session", arg = "SESSION",
            help = "minted holder identity for claimed items"},
          {long = "force", help = "audited repair of another holder's item"},
          {long = "why", arg = "REASON", help = "why --force was needed"}}}},
    {name = "set", summary = "repair ID's title, repo and/or base "
      .. "(at least one; nothing else moves here)",
      spec = {usage = "ID [options]", flags = {dir_flag(),
          {long = "title", arg = "TITLE", help = "the item's title"},
          {long = "repo", arg = "OWNER/NAME",
            help = "the repo its PR lands in; refused on the board — it "
            .. "carries no repo"},
          {long = "base", arg = "BRANCH",
            help = "the branch its PR targets"},
          {long = "session", arg = "SESSION",
            help = "minted holder identity for a claimed item"},
          {long = "force", help = "audited repair of another holder's item"},
          {long = "why", arg = "REASON", help = "why --force was needed"}}}},
    {name = "spec", summary = "replace ID's spec sidecar with FILE",
      spec = {usage = "ID FILE [options]", flags = {dir_flag(),
          {long = "base", arg = "FILE",
            help = "the spec text you read, as the compare-and-swap base"},
          {long = "session", arg = "SESSION",
            help = "the session making the write. Omit to derive it from "
            .. "the environment"},
          {long = "force", help = "rewrite another session's LIVE claim's "
            .. "spec (a stale one needs no force)"},
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
        .. "filled, including the session label this kind's own\nclaim "
        .. "belongs under (also named on the closing verdict line). The "
        .. "verdict\nline names what is still left to fill (a worktree "
        .. "path, a bounce paragraph);\nfill those, then paste the body "
        .. "as the agent's prompt — never\nparaphrase or summarize it, "
        .. "and never hand-write a brief instead: a\nhand-written brief "
        .. "drifts.",
        flags = {dir_flag(),
          {long = "out", arg = "FILE",
            help = "write the filled body to FILE instead of stdout, "
            .. "immune to a channel that decodes escapes"}}}},
    {name = "worktree", summary = "create ID's builder checkout: branch, "
      .. "worktree, bootstrap, all in one command",
      spec = {usage = "ID [options]",
        summary = "create ID's checkout from its confirmed active claim.\n\n"
        .. "Resolves ID's repo through the explicit repository map (or "
        .. "--root), creates\nwork/<handle>/<claim-root-short> at the exact "
        .. "recorded claim base, and adds a\nmatching nested worktree beside "
        .. "the checkout. Existing names refuse. Each already-present\n"
        .. "--ref is copied into refs/spike/<basename>. The bootstrap's own "
        .. "fetch/build is quiet by\ndefault, printing only its "
        .. "PASS/FAIL summary line(s) on success and\neverything on a "
        .. "failure; --verbose streams it verbatim instead.\n\n--review "
        .. "starts the same claim branch at the exact handed-over commit. "
        .. "Gitboard performs no fetch;\nthe caller must make every named "
        .. "commit and ref locally inspectable first. "
        .. "--verbose applies to either\ncheckout's bootstrap.",
        flags = {dir_flag(),
          {long = "root", arg = "DIR",
            help = "local product checkout override; otherwise use the "
            .. "configured repository mapping"},
          {long = "ref", arg = "REF", repeated = true,
            help = "fetch REF into refs/spike/<basename> after "
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
        .. "provider operation or authenticated network request.",
        flags = {dir_flag(),
          {long = "session", arg = "SESSION",
            help = "minted claim identity; default $GITBOARD_SESSION"},
          {long = "head", arg = "SHA", help = "product commit handed over"},
          {long = "url", arg = "URL", help = "optional non-authoritative link"},
          {long = "repo-dir", arg = "DIR", help = "local product checkout; "
            .. "otherwise use the configured repository mapping"}}}},
    {name = "drop", summary = "return ID's lease; the item, blockers "
      .. "included, is untouched",
      spec = {usage = "ID [options]",
        summary = "prepare release of the whole-item claim without changing "
        .. "workflow fields. By default Gitboard prints an exact leased push; "
        .. "--execute runs ordinary Git using caller-owned authentication.",
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
        .. "remote checks or performs a provider write.",
        flags = {dir_flag(),
          {long = "head", arg = "SHA", help = "exact product commit judged"},
          {long = "repo-dir", arg = "DIR", help = "local product checkout; "
            .. "otherwise use the configured repository mapping"},
          {long = "session", arg = "SESSION",
            help = "minted reviewing claim identity; default $GITBOARD_SESSION"},
          {long = "force", help = "record over the distance guard "
            .. "(the session built or specced this item) — repair only"},
          {long = "why", arg = "REASON", help = "why --force was needed"}}}},
    {name = "done", summary = "end ID after locally verifying its landed commit",
      spec = {usage = "ID [options]", flags = {dir_flag(),
          {long = "reason", arg = "REASON", default = "completed",
            help = "completed or not-planned"},
          {long = "by", arg = "CHILD", help = "an outcome's evidence: its "
            .. "completed child, required with --reason completed"},
          {long = "landed", arg = "SHA", help = "landed product commit for "
            .. "completed accepted work"},
          {long = "repo-dir", arg = "DIR", help = "local product checkout; "
            .. "otherwise use the configured repository mapping"},
          {long = "session", arg = "SESSION",
            help = "minted claim identity; default $GITBOARD_SESSION"},
          {long = "force", help = "audited repair past normal completion gates"},
          {long = "why", arg = "REASON", help = "why --force was needed"}}}},
    {name = "show", summary = "the board (no ID), or one item: fields, "
      .. "spec-bar problems, spec, git history",
      spec = {usage = "[ID] [options]",
        summary = "the board (no ID), or one item: fields, spec-bar "
        .. "problems, spec, git history.\n\n"
        .. "Bare `show` renders the top of todo, 8 rows by default; "
        .. "`--todo 0` renders every pullable row at once — the way to "
        .. "see the whole pullable set. No effect with an ID.",
        flags = {dir_flag(),
          {long = "todo", arg = "N",
            help = "how many todo rows to show (0 = all; default 8); "
            .. "no effect with an ID"}}}},
    {name = "publish", summary = "render or explicitly execute prepared leased pushes",
      spec = {usage = "[TRANSACTION...] [options]",
        summary = "render prepared transactions as exact atomic leased Git push "
        .. "commands.\n\nWith no transaction selector, renders every prepared "
        .. "transaction. Nothing executes\nunless --execute is present; ordinary "
        .. "Git then owns all authentication behavior. An executed push exits "
        .. "2 until refresh confirms the fetched refs.",
        flags = {dir_flag(),
          {long = "remote", arg = "NAME",
            help = "Git remote named in the push argv"},
          {long = "execute", help = "explicitly execute the exact rendered Git argv"}}}},
    {name = "refresh", summary = "inspect fetched refs, or explicitly fetch first",
      spec = {summary = "confirm prepared transactions against caller-fetched "
        .. "remote-tracking refs and rebuild\nthe disposable cache. Without "
        .. "--execute, prints the exact fetch command but does not run it.\n"
        .. "--execute runs that same ordinary Git argv before confirmation; "
        .. "credentials remain caller-owned. Exit 2 means publication remains "
        .. "unconfirmed; a lost lease exits 1.",
        flags = {dir_flag(),
          {long = "remote", arg = "NAME",
            help = "Git remote and remote-tracking namespace to inspect"},
          {long = "execute", help = "explicitly execute the exact rendered fetch argv"}}}},
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

local record gitcommands
  CSPEC: flags.CommandSpec
end

local M: gitcommands = {
  CSPEC = CSPEC,
}

return M
