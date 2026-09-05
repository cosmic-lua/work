## Evidence

Carried over from `3IpXih2Xjo6tszK6RmNnG3pQYHj` («tl: pcall-return-shape's
union-with-any design regresses dozens of unrelated call sites tree-wide»),
which diagnosed `cosmic/_teal_engine.tl:256` as one of 3 sites that do
NOT share the zero-return-arity root cause that item's patch actually
fixes. Its own evidence paragraph:

> `cosmic/_teal_engine.tl:256` — a nominal-vs-structural mismatch
> between `Result` and a locally-declared `TlResult`; likewise not
> fixed by the proposed union.

Re-read directly (`cosmic/_teal_engine.tl:122-128,244,253-256`):

    --- Result from Teal's process_string function.
    local record TlResult
      syntax_errors: {TlError}
      type_errors: {TlError}
      warnings: {TlError}
      ast: any
    end
    ...
    local ok, result_or_err = pcall(tl.process_string, input, false, env, name)
    ...
    -- The lazy in-function require keeps tl's own Result record
    -- un-nameable at file scope; TlResult is its structural mirror.
    -- cast: pcall slot 2 is tl's nominal Result, not any
    local result = result_or_err as TlResult

`tl.process_string` is declared with return arity 1 (a single `Result`),
confirmed in the generated declaration:

    $ grep -n "process_string" /home/user/cosmic/o/_types/types_gen/tl.d.tl
    84:  process_string: function(string, boolean, Env, string, ? string): Result

    $ sed -n '15,20p' /home/user/cosmic/o/_types/types_gen/tl.d.tl
      record Result
        ast: any
        syntax_errors: {Error}
        type_errors: {Error}
        warnings: {Error}
      end

`tl.Result` and the file-local `TlResult` have identical fields (modulo
`TlError` vs. `Error`, themselves structurally identical) but are two
separate nominal record types — Teal compares records by identity, not
structure, so `result_or_err` (typed `Result` by the checker, since
`process_string`'s declared arity is 1, not 0) needs the cast to become
a `TlResult` even though every field matches. `require("tl")` is called
lazily inside the function (comment: "the lazy in-function require
keeps tl's own Result record un-nameable at file scope"), which is why
`TlResult` exists as a separate declaration at all rather than the file
just using `tl.Result` directly.

## The question

`3IpXih2Xjo6tszK6RmNnG3pQYHj`'s zero-return-arity patch does not (and
should not try to) touch this: `process_string` returns 1 value, not 0.
The actual question here is unrelated to pcall's return typing at all
— it is whether `TlResult` needs to exist as a separate nominal record
in the first place, given it is declared as a structural mirror purely
to work around `tl.Result` being "un-nameable at file scope" (per the
file's own comment) under the lazy in-function `require("tl")`. Two
directions, neither explored yet:

1. Find a way to name `tl.Result` at file scope despite the lazy
   `require` (e.g. a module-level `require("tl")` used only for typing,
   if that does not reintroduce whatever problem made the require lazy
   in the first place — undiagnosed here), and drop `TlResult` and the
   cast entirely.
2. Or accept the two-nominal-types-one-shape situation as permanent
   (the lazy require has a real reason) and leave the cast as the
   correct, already-legal way to cross it — in which case this item
   resolves as "working as intended," not a defect.

Which of the two applies turns on WHY `require("tl")` is lazy at that
call site — undetermined here; whoever picks this up should read that
call site's own history/comments for the reason before assuming either
direction.

## Non-goals

Not proposing a fix yet — which direction (if either) is right depends
on a fact (why the `require` is lazy) not yet established. Not the
sibling item's zero-return case (`cosmic/shm.tl:146,171`), already
resolved in `3IpXih2Xjo6tszK6RmNnG3pQYHj`. Not `cosmic/sqlite/extras.tl:63,106`
(filed separately: distinct pcall-failure-arm mistyping, not a
nominal/structural mismatch).
