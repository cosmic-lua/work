No change to the verdict kinds, the distance guard, or the head/spec
recording. No merge of a PR whose judged head is not the current head
(the `sha` field guarantees it). No retry loop: a failed landing is one
verdict line the orchestrator acts on.
