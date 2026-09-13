Both readers, same breath (the capture's first option):

1. cosmic (`cosmic/_literal_lex.tl`, short-string scan): on `\`, a
   following `z` consumes the pair and then every whitespace byte,
   newlines included — the scan's raw-newline refusal keeps ending a
   string everywhere else. The emitted token's line accounting counts
   the breaks inside the slice (also fixing the pre-existing y drift
   for `\<newline>`, the other escape that already spanned lines).
   The decoder (`escape_at`'s z branch) already skips newlines and
   needs nothing. Tests: the capture's exact source through
   `literal_test.tl`, plus the engine corpus as an ACCEPT case —
   safe under any pin because a C refusal falls through to this
   lexer for the answer (dispatch in literal.tl), so behavior is
   correct today and merely faster once the C side lands.
2. cosmopolitan (`tool/net/llua.c`, the `esc == 'z'` branch): drop
   the `*q != '\n'` stop so `\z` skips newlines too, and rewrite the
   comment that made the divergence deliberate. Raw newlines not
   behind `\z` still refuse (outer scan). Upstream test updated in
   the same commit; lands as its own PR on the designated branch,
   consumed by a later cosmos pin bump.
