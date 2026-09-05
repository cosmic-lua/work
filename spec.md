## Evidence

A function's `@return` tags and its declared return slots are two statements of one
contract, and only one of them is checked. The doc index carries both — `FunctionDoc`
(`cosmic/doc/types.tl`) has `returns: {Return}` from the tags and `signature: string`
from the source — so the disagreement is a census over the index, no parsing of the
tree needed.

Measured 2026-09-05 at c39fc2f over `o/bin/cosmic`'s embedded index, public
`cosmic.*` modules only (`internal == false`), counting a signature's top-level return
slots (commas outside parens and braces after the closing `):`):

```
public functions: 441; with signature+@param: 324; @param name not in signature: 6; @return count != declared slots: 9
  cosmic.signal.sigsuspend: 3 @return tags vs 2 declared slots `(mask?: Sigset): boolean, string`
  cosmic.child.start:      1 @return tags vs 2 declared slots `(argv: {string}, opts?: Options): Handle | nil, string`
  cosmic.child.run:        1 @return tags vs 2 declared slots `(argv: {string}, opts?: Options): Result | nil, string`
  cosmic.proc.execve:      1 @return tags vs 2 declared slots `(prog: string, args: {string}, env: {string}): nil, string`
  cosmic.proc.execvp:      1 @return tags vs 2 declared slots `(prog: string, argv?: {string}): nil, string`
  cosmic.proc.execvpe:     1 @return tags vs 2 declared slots `(prog: string, argv: {string}, envp?: {string}): nil, string`
```

(three more of the nine are the same shape; the census script is below). All six
`@param` mismatches are one spelling, not a disagreement: the tag reads `@param name?`
while the signature reads `name?: string`. The tree spells optional parameters both
ways in tags:

```
$ grep -rh "^\s*--- @param [A-Za-z_]*? " --include=*.tl cosmic | wc -l
13
$ grep -rh "^\s*--- @param [A-Za-z_]* " --include=*.tl cosmic | wc -l
847
```

Every one of the nine is a fallible function whose doc describes the value and says
nothing about the error slot — the reader of `--docs cosmic.child.run` sees one
`@return` and a signature with two, and the honest-nil rule (AGENTS.md, "a fallible
return has TWO slots") is exactly what the missing tag would state. This is the doc
half of that rule, and it is cheap to hold: the index is built on every build.

The census (`o/bin/cosmic doc_returns_census.lua`):

```lua
local idx = assert(require("cosmic.doc").embedded_index())
local function slots(sig)
  local after = sig:match("%)%s*:%s*(.*)$"); if not after then return 0 end
  local depth, n = 0, 1
  for c in after:gmatch(".") do
    if c == "(" or c == "{" then depth = depth + 1 elseif c == ")" or c == "}" then depth = depth - 1
    elseif c == "," and depth == 0 then n = n + 1 end
  end
  return n
end
for mod, m in pairs(idx.modules) do
  if mod:match("^cosmic%.") and not m.internal then
    for _, f in ipairs(m.functions or {}) do
      if f.signature and #(f.returns or {}) > 0 then
        local d = slots(f.signature)
        if d > 0 and d ~= #f.returns then print(mod .. "." .. f.name, #f.returns, d, f.signature) end
      end
    end
  end
end
```

## Change

1. `_build/doc_returns_test.tl` (new, `--- reads:` the tree's built index
   `o/embed/cosmic/.docs/index.lua` and `cmd/cosmic/embed_gen.tl`): over every
   non-internal `cosmic.*` module's `functions`, for each function with at least one
   `@return` tag, the tag count equals the signature's top-level return-slot count
   (the `slots` walk above, moved into `_tool/doc/exports.tl` or a sibling under the
   cap as `return_slots(signature): integer` with its own unit test: `boolean,
   string` → 2, `{string: any} | nil, string` → 2, `function(Entry): (WalkAction, T)`
   → 1, no return → 0). A function with NO `@return` tags is not judged (a bare-value
   infallible function documents its value in prose today; requiring tags everywhere
   is a different, larger change). Message: `<module>.<name>: <n> @return tags,
   <m> declared slots — <signature>`.
2. The same test normalizes the `?` spelling: a tag `@param name?` and a signature
   `name?:` are the same parameter; a tag naming a parameter the signature lacks
   fails with `<module>.<name>: @param <p> is not a parameter of <signature>`.
   Measured zero such cases once `?` is normalized, so this lands green.
3. Fix the nine in the same PR: add the error-slot `@return string` tag each is
   missing (for `execve`/`execvp`/`execvpe`, whose slot 1 is `nil` on the only path
   that returns, the first tag documents that slot as "nil — the exec did not
   happen"). Doc-comment edits only.
4. `_tool/doc/init.tl`'s `parse_annotations` is untouched: the tags are read as they
   are; the gate compares.

## Non-goals

Requiring `@return` on every function. Checking tag TYPES against slot types (the
`return_type` text is free-form today — `string?`, `string|nil`, `string | nil` all
occur; normalizing it is its own item). Internal modules (the `_` rule: not API, not
rendered). Cosmo `.d.tl` declarations.
