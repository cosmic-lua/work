- **No C.** Do not edit `libc/runtime/zipos-open.c`,
  `libc/runtime/zipos-close.c` or `libc/runtime/zipos.internal.h`, do
  not build, and do not open a pull request against
  whilp/cosmopolitan. A research slice that also writes the code
  cannot say which of the two its findings judged.
- **Do not remove the `next` member either.** It is the evidence this
  slice reads; whether it stays or goes is the sibling slice's
  decision, made with the answer in hand.
- **Do not re-measure the parent's numbers.** The 8.7x, the 10
  syscalls and the ~220µs boot excess were measured adversarially in
  the capture and are carried into Evidence above; this slice spends
  its time on the question they do not answer. A perf re-measure is
  the sibling's `Acceptance`, under the `optimize` skill's gates.
- **Do not settle the C-layer build question.** Board item
  `3IHHJcVr` (`o//depend` broken: header edits never rebuild) governs
  how a C-layer A/B is run; it is the sibling's blocker if it is
  anyone's, not this slice's subject.
- **Do not widen into the deflate finding.** The parent records that
  `__zipos_load` inflates deflated members fully at `open()`; cosmic
  ships every `.lua` member STORED, so it is upstream hygiene with no
  cosmic win. It stays recorded, not proposed, and not researched here.
