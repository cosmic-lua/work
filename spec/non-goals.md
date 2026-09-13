- Not a contract-shape/return-tuple question — this is a memory-safety
  crash, unrelated to the nil-admission census that surfaced it.
- Not touching the six bindings' other behavior (successful spawn/exec
  paths, environment handling on valid input) beyond the crash fix.
