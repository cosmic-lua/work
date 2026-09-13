Amend `docs/decisions/d23-check-throws.md` — an AMEND, not a
supersession: D23's call stands and a fact under it moved, so the
original body stays exactly as written and a final
`- **amended 2026-08 (<why>):**` bullet is appended, with `status`
changed from `active` to `amended 2026-08 (...)`. The title does not
advertise the closed list, so it is not retitled and the number does
not move (`skills/decide/SKILL.md`, `## amend, supersede, correct`).

**The pick is made: the exemption is RULED, not enumerated.** Write
the amendment to say, in the record's voice:

> a `cosmic.*` module may `assert` a `cosmo.*` binding return whose
> declared `| nil` is UNREACHABLE for the arguments that call passes —
> the binding's union is honest for an arbitrary caller-supplied value
> and impossible for the constants the module hands it — provided the
> assert carries a trailing `-- assert: <why the nil cannot occur>`
> comment naming the reason, the way a cast carries its `-- cast:`.
> This licenses no other throw: a REACHABLE runtime failure stays
> D22's shape (no caller may proceed without the value) and a caller
> contract violation stays D22's other shape, each needing its own
> record.

Why ruled and not a third enumerated module, recorded in the
amendment's own reasoning:

- The shape recurs and is not about `cosmic.time`. Board item
  3IPktATw is the same shape at a different binding —
  `cosmo.path.join` declaring `string | nil` for a nil no caller can
  reach, **26 census sites**. An enumerated list needs a new
  amendment per module; a rule an author can apply without asking
  needs none, which is what a decision record is for.
- The unreachability argument is checkable by a reader at the site,
  and the `-- assert:` comment is where it is checked. An enumerated
  seat records only that somebody once said yes.
- It is a genuinely different category from the two D23 already
  carries, so it does not relitigate either: check's is "the caller
  is the runner", D22's is "no caller may proceed", and this one is
  "the union member cannot occur here".

Then bring the prose D23 governs into line:

- `AGENTS.md:237` — the rule under `### Error Handling Patterns`:
  "never throw from library code — `cosmic.check` alone is exempt
  ([D23](docs/decisions/d23-check-throws.md)); the CSPRNG's
  throw-on-failure is the only other exception" — restates the rule
  in place, naming the unreachable-nil assert as the third sanctioned
  shape and keeping the D23 link.
- `AGENTS.md:85` — "**error handling**: return `value, string` … never
  throw from library code." — the one-line summary, left as a summary;
  change it only if it would now be false.
- `bin/cosmic _docs/derive.tl` rewrites D23's row in
  `docs/decisions/README.md` (line 60 today, `status` column `active`).
  Never hand-edit those rows.

Measured 2026-08-26: `docs/decisions/d23-check-throws.md` is 44 lines
with `status: active` (line 4) and 0 `- **amended` bullets; `AGENTS.md`
is 464 lines; the only in-tree references to D23 outside the record and
its index are `AGENTS.md:237` and
`docs/decisions/d20-naming-charter.md:124`
(`grep -rn 'd23-check-throws\|D23' --include='*.md' --include='*.tl' .`).
