- no dedup-on-decode: silently folding repeats would hide the writer bug
  that produced them; the gate refuses, the writer fixes.
- no change to the `block`/`unblock` verbs — `block` already refuses an
  edge that exists (its `kept` rebuild), so the only writers of repeats
  are file edits, which is exactly what validation exists to catch.
- no other validation deepening.
