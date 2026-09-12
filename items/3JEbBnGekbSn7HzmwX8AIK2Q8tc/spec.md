## Change

Implement chunk 2 of Wdaw_QfXv after chunk1: add the internal diagnostic
checkpoint codec and filesystem boundary without enabling diagnostic runs.
Repo cosmic-lua/cosmic. Parent spec freezes the complete protocol and limits.

Add `_fuzz/checkpoint.tl` and `_fuzz/checkpoint_test.tl`. Export typed Snapshot
and Decoded records; Snapshot fields seed,iters,iteration,phase,stage,draws,input.
Decoded has valid boolean, snapshot optional by invariant, error string.
encode returns a record containing valid/bytes/error; decode returns Decoded;
write(path,snapshot) returns boolean,string; read(path,seed,iters) returns
Decoded. Nil-valued fields are narrowed by valid, no blind casts, throwing
public helper, load/eval, or new nil-return baseline row.

Use exact `>c8i8i8i8I1I1i8I4` header (46 bytes), magic CFUZZ001, enum values,
raw payload and validation from the parent. Stored input cap is1MiB; normalize
a larger checking snapshot to phase4 with draws0/input empty, preserving
iteration/stage. Never silently truncate bytes. Encode must reject invalid
metadata too. read uses fd.open + bounded reads of at most46+1048576+1 bytes,
closes the descriptor on success/error, and rejects one extra byte; do not
fs.read an arbitrarily large file. write delegates to fs.write atomic=true,
mode0600, handles pack/filesystem errors as values. In a fresh directory the
last complete snapshot is authoritative; no old record from another run can
be accepted. Compare expected seed and iters at read/decode boundary. The
per-process directory, not a user-supplied property filename, scopes identity.

Permanent tests: binary string containing every byte0..255, empty input,
primary/shrink/verify stages, each phase, exactly-cap and cap+1 strings,
signed seed boundaries, missing file, invalid magic/enum/counts/iteration,
wrong seed/iters, short header/body, declared length larger/smaller than body,
trailing bytes, and disk file cap+one. Invalid/non-check phase never returns
an attributable input. Assert packsize=46 rather than duplicating a guessed
offset. Use one valid fixture to mutate header fields via pack, not hand
offsets in every test. Atomic write/read round-trip must preserve NUL bytes.
An injected write failure must return false plus a useful error; decoding
arbitrary malformed bytes must not throw. No requirement to simulate disk
crash consistency: fs.write's implementation/tests own atomic replacement.

The baseline head's relevant APIs are in cosmic/fs/file.tl: write48,
write_atomic92; cosmic/fs/init.tl: temp_dir163, temp_fd166. Commands:
`rg -n 'local function write|write_atomic =|temp_dir:|temp_fd:'
cosmic/fs/file.tl cosmic/fs/init.tl`. Both new files start at0 lines; target
~180 codec/IO +~180 tests, each below500. This creates internal source files,
not tracked format migrations or a published API. All headers are protocol
version1; changing them in the next chunk is a spec violation.

Run `bin/cosmic --make test _fuzz/checkpoint_test.tl`, then full ci: PASS.
Negative controls: omit payload length validation, treat empty as absent,
accept unknown phase, remove bounded read, or ignore expected seed; their
corresponding tests must fail. Passing this chunk alone makes no attribution
claim; integration is the next dependency.
