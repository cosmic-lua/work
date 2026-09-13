## Change

`_work/gitclaim_cli.tl`'s `handover_ancestry_refusal` prints a diagnosis
that is the OPPOSITE of what its own code tests, and the remedy it then
names only makes sense under the code's reading. Measured on the live
board, 2026-09-13, against item 3JEx2b51 (handover
`c5eb284aec6c0b730c605e5c16ccad30cde35271`, local `main` at
`e56fc09f3c6b5faa020a281c3955429c3af5ce54`):

```
$ gitboard claim r1o1_8g3F --session <fresh> --execute
refused 3JEx2b51…: 3JEx2b51 already has a commit handover (c5eb284aec6c…)
  that local e56fc09f3c6b… cannot reach — a fresh review claim must not
  silently capture an unrelated base; reposition main … to (or behind)
  the handover …
$ git -C /home/user/work merge-base --is-ancestor c5eb284aec6c e56fc09f3c6b; echo $?
0     # the handover IS an ancestor of main: main CAN reach it
$ git -C /home/user/work merge-base --is-ancestor e56fc09f3c6b c5eb284aec6c; echo $?
1     # main is NOT an ancestor of the handover: the handover does not
      # descend from main — THIS is what the code tests
```

The function calls `commit_evidence.verify_lineage(root, base, handover)`,
which asks whether `handover` DESCENDS FROM `base`. That is the right
question for a review claim — the review diffs `base..handover`, so the
handover must be ahead of the base — and the remedy ("reposition main to
or behind the handover") is right for it. The message, though, says the
base "cannot reach" the handover, which is reachability in the other
direction and is false in exactly the case the guard fires on: a board
whose main has moved PAST the handover. A caller who checks the claim
with git, as this one did, finds it contradicted and spends the next
several commands proving the tool wrong before reading its source.

Rewrite the message to state the relation the code tests, in the
direction it tests it: the handover does not descend from local `main`
(`main` has moved past it, or sits on an unrelated line), and a review
claim must diff from a base the handover is ahead of. Keep the remedy
text as it is; it was already right. `_work/gitclaim_handover_ancestry_test.tl`
already exercises the refusal — extend its assertion to pin the corrected
wording so the message cannot drift back.

## Non-goals

Changing what the guard tests. `verify_lineage(base, handover)` is the
correct check for a pre-merge review and stays.

Making a review claim possible after the handover has merged. That is a
model question — the claim base is captured as current main by design —
and a caller who needs it can supply `--repo-dir` pointing at a checkout
whose `main` sits at the handover's parent, which this session did. Not
this item's to solve or to document beyond the message.
