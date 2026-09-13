`take ID --pr N`'s handover: leave the `reviewer:` field CLEARED (or
set to a value `take` itself recognizes as "not a live claim," e.g.
empty) rather than the calling session's own label — the field means
"who currently holds the verdict-awaiting claim," and nobody does
until a reviewer actually takes it. A genuinely fresh `take ID
--session review-...` then succeeds without needing `--force`; taking
over an ACTUALLY live review (one a reviewer claimed and hasn't yet
verdicted) keeps requiring `--force --why` exactly as it does today.
