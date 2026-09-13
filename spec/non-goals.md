The `.gcda` byte format and the gcc-14 `gcov_info` layout the file
mirrors are a wall; do not change record shapes. A fork-time counter
reset (`__gcov_fork`) is a separate item: with the lock, a child and
parent both adding the pre-fork counts is double-counting, not loss.
