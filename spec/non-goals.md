Re-litigating whether tails should be collision-checked at mint time (out
of scope — «GkFk_U7L5»'s own spec already treats this as unreachable in
practice); any other part of «GkFk_U7L5»'s merged diff, which review found
otherwise sound (fresh `bin/cosmic --make ci` green on the PR head, scope
matched the spec, a mutation test on the "never loads the whole board"
guard confirmed real).
