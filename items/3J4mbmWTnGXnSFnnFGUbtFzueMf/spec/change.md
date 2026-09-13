Make handover/verdict state commit-coherent. A handover at a head different
from the accepted verdict's head must not remain accepted under that old
verdict. Define and implement the smallest safe transition that permits a
fresh review verdict for the new exact handover, while preserving the prior
verdict as history. Ensure `done` cannot use an acceptance whose head differs
from the current handover.

Add an end-to-end regression covering: take head A, accept A, reacquire after
an external check failure, take descendant head B, observe review-required
state, accept B, then allow completion only for B. Exercise durable store
reopen/cache projection and the CLI refusal/acceptance boundaries.
