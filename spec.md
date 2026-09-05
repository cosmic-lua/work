## Change

`gitboard new`'s usage says `TITLE [options]`, and a title that begins with a dash is
refused as an unknown option — the parser (`cosmic.flags`, the pinned cosmic's) stops
at `--` but nothing on gitboard's side says so. Reproduced 2026-09-05 against a
throwaway board:

```
$ gitboard new "--docs foo: a title"
unknown option: --docs foo: a title (try --help)
$ gitboard new -- "--docs foo: a title"
gitboard-new: 3ItPrEBpLmQjjyrVnqAvdDFKGJE enters triage — attach it under something, or compare it
```

Titles that name a CLI surface (`--docs ...`, `--check types ...`) are ordinary on this
board — three were filed on 2026-09-05 and each needed the `--` a reader has no way to
learn from the refusal. The parser's message is cosmic's to fix (the item filed beside
this one on cosmic-lua/cosmic, which reaches gitboard on its next pin bump); what is
gitboard's is its own usage line and the `new` help page.

1. `_work/gitboard.tl:138`: the `new` command's usage becomes
   `[--] TITLE [options]`, and the command's long help (the text `gitboard help new`
   prints, `_work/doctrine.tl` or wherever `new`'s description lives — `grep -n
   "friction:. title is refused" _work/*.tl` finds it) gains one sentence after the
   `friction:` paragraph: `A title that begins with a dash goes after `--`:
   `gitboard new -- "--docs ..."`.`
2. `_work/gitboard_test.tl` (or the test that renders `help new` today — `grep -n
   "help new\|usage: gitboard new" _work/*_test.tl`): assert the usage line and the
   sentence.
3. The `skills/work/SKILL.md` bootstrap in cosmic-lua/cosmic is NOT edited: the
   doctrine ships with the tool, and this is the tool's page.

## Non-goals

Changing the parser or its message (cosmic's item). Any other verb's usage: `spec ID
FILE`, `attach ID PARENT` take ids and paths, which never begin with a dash.
