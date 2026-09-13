No plan/ready refinement claims: moves are already serialized by
push-as-CAS, WIP limits cap the racers, and the measured waste there
was spec churn, not builds — revisit if measured. No jitter in
`next`: reviewer claims make the fan-out (the second reviewer sees
the claim and takes the next item), so determinism stays. No change
to do-claim semantics or the 4-hour lease. No reviewer authority:
verdict stays valid from any non-builder.
