CORRECTION to this item's premise, measured 2026-09-16 against the pinned
release. The title says "an unknown option is a refusal line, not the help
page". A refusal line already exists. What is wrong is what follows it.

    $ gitboard take jifZ_JzNb --execute
    unknown option: --execute (try --help)      <- line 1, correct and specific
    usage: gitboard <command> [options]          <- lines 2-55, the whole
    ...                                             top-level help page plus
                                                    the doctrine topic listing

55 lines total. Same shape on every verb tested:

    gitboard new --check foo   -> "unknown option: --check (try --help)"   + 54
    gitboard snapshot --abandon-> "option requires a value: --abandon"     + 54
    gitboard take --execute    -> "unknown option: --execute (try --help)" + 54

The site is `_work/gitboard.tl:133-139`: `derr` is written to stderr, and then
`flags.command_help(CSPEC)` and `doctrine.listing()` are written after it.

So the fix is to stop printing the help dump, not to add a refusal. Consider
also that a refusal at the TOP of 55 lines is invisible to a caller using
`| tail -N`, which is the normal way to read verbose board verbs — the
orchestrator reported this defect twice as "prints the help page instead of a
refusal" precisely because `| tail -4` hid line 1. Whatever replaces the dump,
the refusal should survive truncation from either end.

The item's other half is already satisfied: `gitboard new -- "--title"`
accepts a dash-leading title through the `--` terminator today. What may
remain there is the usage text, which «X3Fv_c3NJ» already owns.

Scope note: this behaviour is not confined to `new`. It reproduced on
`snapshot` and `take`, so the fix belongs in the shared dispatcher path rather
than in one verb.