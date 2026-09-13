Not changing `head_moved`'s semantics, and not adding a runtime assertion
that `judged` is canonical — the verb's existing refusals already make an
empty head unreachable from the live path, and this item is about saying so
where it is read. Not touching `head_refusal`.
