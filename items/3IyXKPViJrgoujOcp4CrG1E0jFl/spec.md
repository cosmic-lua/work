## Evidence

`gitboard new --repo cosmic-lua/cosmic --parent P --after A --spec-file F "--check lint --max-lines: one end-to-end case …"` printed the verb list (the top-level help page) and nothing else — no `gitboard-new:` line, no "unknown option" — twice in one pass (2026-09-06), because the title begins with `--` and the argument parser read it as a flag. A title that names a flag is the ordinary case for a CLI project. `gitboard help new` does not mention `--` as an end-of-options marker.

## Change

`gitboard new` accepts `--` as the end of options (everything after it is the title, exactly as POSIX getopt does), and an unknown option is refused with `gitboard-new: REFUSED: unknown option --check (a title that starts with a dash goes after --)` rather than the help page. Test in the verb's test file: a title beginning with `--` after `--` is stored verbatim; the same title without `--` is refused with that line.

## Non-goals

No change to any other verb's parsing; no change to how titles are stored.

## Access

cosmic-lua/work, read and write on a branch; no other repository.

## Ready when

`gitboard new --repo R --parent P --spec-file F -- "--check lint: t"` files an item whose title starts with `--check`, and the same call without `--` prints the refusal line and no help page.
