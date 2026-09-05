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
  .. "everywhere; item branches are named\nby the id's first 8 characters — a "
  .. "different string from the handle.",
  commands = {
    {name = "init", summary = "prepare a state repository (a git repo, if needed)",
      spec = {flags = {dir_flag()}}},
    {name = "new", summary = "open an item titled TITLE; role comes from the graph",
      spec = {usage = "TITLE [options]",
        summary = "open an item titled TITLE; role comes from the graph.\n\n"
        .. "A `friction:` title is refused unless its spec (--spec-file) "
        .. "names every agent this\nsession claimed work under since the "
        .. "pass began, one `## <kind> <handle>` heading\neach; "
        .. "--force --why files it anyway (a pass whose transcripts are "
        .. "gone).",
        flags = {dir_flag(),
          {long = "parent", arg = "ID", help = "the item this decomposes"},
          {long = "before", arg = "X",
            help = "place it immediately before X among its new siblings "
            .. "(needs --parent)"},
          {long = "after", arg = "X",
            help = "place it immediately after X among its new siblings "
            .. "(needs --parent; at most one of --before/--after)"},
          {long = "spec-file", arg = "FILE", help = "spec markdown sidecar"},
          {long = "repo", arg = "OWNER/NAME",
            help = "the repo its PR lands in; default is the board's origin"},
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
            .. "(at most one of --before/--after)"}}}},
    {name = "compare", summary = "record that ID outranks OTHER "
      .. "(a standing reverse edge is reversed)",
      spec = {usage = "ID OTHER [options]", flags = {dir_flag()}}},
    {name = "rank", summary = "position ID among its siblings: before or "
      .. "after X, or last; roots rank against roots",
      spec = {usage = "ID --before X | --after X | --last [options]",
        summary = "position ID among its siblings: before or after X, or "
        .. "last.\n\nID and X must be siblings — the same parent, or both "
        .. "roots. X absent from its\nparent's order is refused as "
        .. "unpositioned: rank X first, or use --last.",
        flags = {dir_flag(),
          {long = "before", arg = "X", help = "place ID immediately before X"},
          {long = "after", arg = "X", help = "place ID immediately after X"},
          {long = "last", help = "place ID last among its siblings"}}}},
    {name = "hold", summary = "mark root ID held: its win condition verified; "
      .. "intake walks past it until evidence is filed under it",
      spec = {usage = "ID [options]", flags = {dir_flag(),
          {long = "reason", arg = "WHY",
            help = "what verified the win condition, and how"}}}},
    {name = "unhold", summary = "clear root ID's hold marker by hand "
      .. "(filing a child under it clears it too)",
      spec = {usage = "ID [options]", flags = {dir_flag()}}},
    {name = "block", summary = "record that ID waits on BLOCKER",
      spec = {usage = "ID BLOCKER [options]",
        summary = "record that ID waits on BLOCKER, the reason on the "
        .. "item.\n\nAn item that cannot proceed — a spec gap, a reopened "
        .. "decision, a falsified\npremise — is never dropped bare. The "
        .. "procedure, in this order:\n\n"
        .. "  1. `new '<the question>' --parent <ID's parent> --spec-file Q.md`\n"
        .. "     (parented, so the question is placed and takeable)\n"
        .. "  2. `block ID <question> --reason '<what cannot proceed>'`\n"
        .. "  3. `drop ID --why 'blocked on <question>'` if holding the claim\n\n"
        .. "ID is then never offered while the question is open, and the "
        .. "question's\n`done` unblocks it by itself — no unblock needed. "
        .. "A blocker is ordered up\nby what waits on it, so blocking lifts "
        .. "the question's place in the queue.",
        flags = {dir_flag(),
          {long = "reason", arg = "WHY",
            help = "what concretely cannot proceed until BLOCKER ends"}}}},
    {name = "unblock", summary = "drop BLOCKER from ID's blockers",
      spec = {usage = "ID BLOCKER [options]", flags = {dir_flag()}}},
    {name = "set", summary = "repair ID's title, repo and/or base "
      .. "(at least one; nothing else moves here)",
      spec = {usage = "ID [options]", flags = {dir_flag(),
          {long = "title", arg = "TITLE", help = "the item's title"},
          {long = "repo", arg = "OWNER/NAME",
            help = "the repo its PR lands in"},
          {long = "base", arg = "BRANCH",
            help = "the branch its PR targets"}}}},
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
        flags = {dir_flag()}}},
    {name = "take", summary = "claim ID: the pull (spec bar and doing "
      .. "bound apply), its review when it awaits a verdict, or record "
      .. "its handover (--pr N for a diff, --result for a research spec)",
      spec = {usage = "ID [options]", flags = {dir_flag(),
          {long = "session", arg = "SESSION",
            help = "the claiming session. Omit to derive it from the "
            .. "environment"},
          {long = "pr", arg = "N",
            help = "record the PR that hands the build over for review"},
          {long = "result", help = "record the research handover: the "
            .. "spec as it stands is the deliverable, awaiting a verdict. "
            .. "The claim holder's own motion; never with --pr"},
          {long = "force", help = "take over another session's LIVE claim "
            .. "(a stale one needs no force), or skip the take gates"},
          {long = "why", arg = "REASON", help = "why --force was needed"}}}},
    {name = "drop", summary = "return ID's lease; the item, blockers "
      .. "included, is untouched",
      spec = {usage = "ID [options]",
        summary = "return ID's lease: the claim (or the review claim "
        .. "alone) releases; the\nitem, its blockers included, is "
        .. "untouched.\n\nA bare drop asserts the WORKER stopped — a dead "
        .. "wave agent, a session out\nof budget, a review nobody can "
        .. "finish — so the item is safe to re-offer\nas-is. An ITEM that "
        .. "cannot proceed is never dropped bare: `new` the\nquestion, "
        .. "`block` ID on it, then drop (see `help block` for the "
        .. "procedure).",
        flags = {dir_flag(),
          {long = "why", arg = "REASON",
            help = "why the session lets go (a dead agent, a build out of "
            .. "budget) — worker-side, never the item's gap"},
          {long = "session", arg = "SESSION",
            help = "the dropping session. Omit to derive it from the "
            .. "environment"},
          {long = "force", help = "drop another session's live claim"}}}},
    {name = "verdict", summary = "record a review verdict on a PR or a "
      .. "research handover (`take --result`); its effect follows",
      spec = {usage = "ID KIND [options]", flags = {dir_flag(),
          {long = "pr", arg = "N", help = "the PR the verdict judges; a "
            .. "research handover has none — omit --pr and --head, the "
            .. "verdict judges the spec revision the handover recorded"},
          {long = "head", arg = "SHA", help = "head commit it judges"},
          {long = "session", arg = "SESSION",
            help = "the reviewing session; it rides in the commit "
            .. "subject. Omit to derive it from the environment"},
          {long = "force", help = "record over the distance guard "
            .. "(the session built or specced this item) — repair only"},
          {long = "why", arg = "REASON", help = "why --force was needed"}}}},
    {name = "done", summary = "end ID, recording why (an accepted PR is "
      .. "verified merged first)",
      spec = {usage = "ID [options]", flags = {dir_flag(),
          {long = "reason", arg = "REASON", default = "completed",
            help = "completed or not-planned"},
          {long = "force", help = "end an item under an unjudged PR, or "
            .. "without reading its merge"},
          {long = "why", arg = "REASON", help = "why --force was needed"}}}},
    {name = "show", summary = "the board (no ID), or one item: fields, "
      .. "spec-bar problems, spec, git history",
      spec = {usage = "[ID] [options]", flags = {dir_flag()}}},
    {name = "sync", summary = "rebase onto the remote's state",
      spec = {flags = {dir_flag()}}},
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
