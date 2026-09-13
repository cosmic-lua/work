- Does not itself fix `unix.sigaction`/`unix.setitimer`/`unix.gmtime`/
  `unix.localtime` — each is its own capture, blocked on this one so
  they land second and match whatever mechanism this item settles on.
- Does not re-litigate `unix.clock_gettime` (#277) — a different
  function, already settled, not part of this deviation family.
