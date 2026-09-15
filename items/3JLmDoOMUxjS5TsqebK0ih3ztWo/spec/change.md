Add `experiments/` to `.cosmicignore`, so the five recorded experiment
scripts stop being compiled, format-checked and lint-checked by every
gate run.

All five are in the build model today —
`grep -o 'experiments/native/[a-z_-]*\.tl' o/project.mk | sort -u`:

    experiments/native/bounded-mutations.tl
    experiments/native/migration-mutations.tl
    experiments/native/mutation_check.tl
    experiments/native/mutations.tl
    experiments/native/read-mutations.tl

`.cosmicignore` currently lists only board state —
`cat .cosmicignore` -> `items/` and `lanes_state.tl`.

AGENTS.md describes the tree as historical records preserved at their
recorded source revisions, which is the case for exclusion: a frozen
artifact tracking today's lint and style rules is churn, and the
`.cosmicignore` mechanism already exists for "literal data, not
sources".
