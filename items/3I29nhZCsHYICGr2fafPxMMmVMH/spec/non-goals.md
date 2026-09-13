- no lock, no waiting, no o/-wide serialization — the sibling capture
  owns the writer half.
- no change to `replace_if_changed`'s unchanged-bytes skip or to the
  runner's use of it (`_make/testrun.tl:114`) beyond what the shared
  `build()` path picks up.
- no self-check inside the artifact: a payload-less binary has no
  cosmic code to run, which is WHY the check lives in the build.
