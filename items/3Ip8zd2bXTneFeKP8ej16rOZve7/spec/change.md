`_cli/nilreturn.tl:318-325` treats EVERY identifier spelled `type` as a
possible alias and hands it to `skip_type_alias` (118-134), which decides by
what FOLLOWS: `NAME =` then a type. A field access `t.type` at the end of a
line, followed by a statement `name = ...`, has the same three tokens, so the
alias path consumes the right-hand side as a TYPE: `name = function(): string
... end` is eaten by `parse_type` (no `fn` frame opens, the body's `end` pops
the frame beneath it, and the lie inside is charged to nobody), and `name =
record ...` opens a `fields` frame no `end` ever pops. Both unbalance the walk
(Evidence), which `_build/nil_returns_test.tl`'s tree-wide balance gate turns
into a failing `--make ci` for whoever writes that shape. The same class
`d639b092` closed for `record`/`interface`/`enum`/`macroexp` with a
previous-token tell (`opens_body`, 175-200).

`_cli/nilreturn.tl` (371 lines): in `walk`, gate the `type` branch on the
previous token exactly as `opens_body` does — take a new
`opens_alias(tokens, i, stack): boolean` beside `opens_body`: `tokens[i]` is
the identifier `type`, `tokens[i+1]` is an identifier, and either `tokens[i-1].tk`
is `local`/`global`, or the top frame is `fields` and `ends_item(tokens[i-1])`
(a record body's `type Foo = ...` item). Call it from the `elseif` at 318;
when it is false fall through to the `i = i + 1` default. `skip_type_alias`
keeps its body but drops the now-redundant `name.kind ~= "identifier"` guard
(keep the `eq` guard). Update the doc at 101-117 and the `skip_declaration_head`
note at 59-66 (which already names `type` as a stop word) to say the walk
reaches `type` only after `local`/`global` or at item start.

One-line alignment in `_cli/returns.tl:286-301`: `opens_macroexp` there
accepts `macroexp NAME` with no previous-token check, while
`_cli/nilreturn.tl:231-232` requires `local`/`global` before it; give
`returns.tl`'s the same `prev.tk == "local" or prev.tk == "global"` condition
so the two readers of one grammar agree (harmless today only because
`params_open` is same-line, 251-270).

Tests the diff carries, in `_build/nil_returns_test.tl` (428 lines; add to
the existing fixture root rather than a new test if the file nears the cap):
- fixture `type_access.tl` = the first snippet below; expect
  `got["cosmic/type_access.tl"] == 1` (handler's lie counted) and the file
  absent from `nilret.unbalanced(root)`.
- fixture `type_record_assign.tl` = the second snippet; expect no count and
  balanced.
- control: `local type Alias = integer` at module scope and `type Inner =
  record ... end` inside a record body still open/consume as today
  (the `field_access` fixture from `d639b092` already covers the record half;
  add the module-scope alias line to it).
- `_cli/returns_test.tl` (221 lines): `local x = t.macroexp` followed by a
  line `foo(1)` yields no diagnostic before and after — pins the alignment
  is behaviour-preserving.
