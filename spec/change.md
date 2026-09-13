Decide one of:
1. Accept the shape as a deliberate, documented exception (the offset
   is genuinely useful for a caller that DOES want it, and re-deriving
   a line number from a byte offset without an offset would cost every
   caller a full re-scan) — record this in the binding-contract-shape
   rule in `AGENTS.md`; no code change; or
2. Normalize: fold the offset into the error string itself (e.g.
   `"<offset>: <message>"`, parsed by a caller that wants structure) so
   slot 3 is dropped and the tuple returns to 2 slots uniformly with
   the rest of the codec/parse family (`DecodeJson`, `DecodeHex`, etc).
