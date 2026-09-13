- **Do not touch `whilp/cosmopolitan`.** No `definitions.lua` edit, no
  C change, no cosmos pin bump, no type regen. The C contract is honest
  and stays frozen; the defect is this side's.
- **Do not add a cast at any site.** `assert` plus its `-- assert:`
  comment is the licensed shape; a cast is not.
- **Do not add guards at the 26 downstream sites.** They close because
  the wrapper's return is a plain `string`; a diff that also guards them
  has not understood the cascade.
- **Do not change `join`'s signature or `cosmic.fs`'s re-export.** It is
  already `(...: string): string`, and `cosmic.fs.join` is the public
  name AGENTS.md's mapping table names.
- **Do not touch `3p/tl/tl_test.tl:17`.** It is a test site under `3p/`
  and belongs to the `check.must` sweep, board item 3IQfILPQ.
- **Do not fix sites belonging to other producers.** This slice owns one
  declaration; the census rows counted above include others.
- **Do not add a lint for the `-- assert:` convention.** Board item
  3IQfhI33.
