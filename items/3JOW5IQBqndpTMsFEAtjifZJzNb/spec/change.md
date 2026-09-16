`brief review`'s template tells every reviewer their checkout "has no `o/3p`
cache yet" and to run `bin/cosmic --make fetch` and `--make build` before
reading anything. For every worktree `handoff --fetch` created — which is how
review checkouts are made — that is false: the handoff already fetched and
built, and the reviewer's first two commands are pure waste.

Six reviewers in one session were handed that instruction. Each cost a
download and a build, or cost a caller a note in the prompt telling them to
ignore their own brief. One reviewer reported the mismatch as friction
unprompted; another noticed `o/3p` did not even exist yet the run worked
anyway, and spent calls working out why.

Make the template say what is true of the checkout it is describing. The
handoff knows whether it fetched — it passes `--fetch` to `worktree` itself —
so the brief can state the prepared state rather than guessing at a cold one.
A brief that must be contradicted by its caller to be correct is worse than
no brief.

Check `brief builder` for the same sentence while you are there; the builder
worktree is prepared the same way.
