Accelerate JSON strings containing only the decoder's ASCII class with
a bounded prefix scan and direct `lua_pushlstring` when the scan reaches
the closing quote. Preserve the existing buffered string parser for all
other inputs, feeding it the already-scanned prefix without rescanning.
This targets cosmic's `json_decode_large` and long string workloads via
cosmo.DecodeJson. No SIMD, word loads, parser replacement, public surface
change, UTF-8 repair, or changes to the old fallback's ASCII loop.

Four dependency-ordered children cover compatibility tests, checked
performance scenarios, the C fast path, and the released cosmic pin plus
independent end-to-end verification. All four chunks are implemented and
validated and have landed through their normal protected merges. The measured implementation
record below supersedes the original scouting estimate.

Implementation order (each earlier item is a prerequisite child of the next):

1. [Compatibility matrix and differential corpus](https://github.com/cosmic-lua/work/blob/items/3JDHcdRYLy1FFN57VNbZoH1ElpH/spec.md)
2. [Checked string benchmarks](https://github.com/cosmic-lua/work/blob/items/3JDHcYe1whiQnoUvqfAEw74nBaa/spec.md)
3. [Bounded C fast path](https://github.com/cosmic-lua/work/blob/items/3JDHcUarYJewnEbR6YEa6GmolvM/spec.md)
4. [Release pin and final verification](https://github.com/cosmic-lua/work/blob/items/3JDHcRko4zUF2e7DYHBp8Ct8YDi/spec.md)
