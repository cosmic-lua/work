Same shape fix as the `re.Regex:search` capture (they are the same C
function); land together. Once slot 2 no longer double-duties,
`cosmic/re.tl:184-203` (`match`) can drop the `if caps then` runtime
disambiguation for a plain type narrow.
