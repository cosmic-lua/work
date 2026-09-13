No matcher, no rewrite/splice here. `span_start`/`span_end` take
`Node`; deriving a byte offset from `(y, x)` for splicing is the
rewrite item's job (it also needs the source text, which this module
does not hold).
