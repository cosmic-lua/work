- **The prepare/publish/refresh split stays.** The two-step confirm is
  what makes a lost race visible; this change only makes the pause
  legible.
- **No `--execute` flag is added to the eight verbs.** That is a real
  question and a different change: it would put a push behind `done`,
  `spec` and `take`, each needing its own confirmation handling, and it
  would make the eight diverge from the one choke point they share
  today. File it separately if it is wanted.
- **No verdict line changes.** `gitboard-spec: ... replaced`,
  `gitboard-done: ...` and the other seven closing lines keep their exact
  current text; they are what callers grep for and what
  `bin/gitboard help bar`'s "read the verdict line" guidance depends on.
  The `NOT PUBLISHED` line lands immediately above them.
- **`_work/gitclaim_cli.tl` is not touched.** `claim`, `renew` and `drop`
  already carry both the flag and the wording.
