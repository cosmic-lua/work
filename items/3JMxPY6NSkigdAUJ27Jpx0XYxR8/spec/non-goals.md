Whether the archive check should consult the legacy namespaces at all on a
format-6 board is NOT settled here. The live board is `refs/heads/state`; the
witness guards a migration whose sources are frozen upstream by a ruleset that
"refuses creation/update/deletion, and has no bypass or exclusions"
(`gitboard help native`), so a clone-local comparison may be redundant. That is
a design call with its own evidence, and removing the check is a different
change from making its refusal legible. This item only makes an unfetched
namespace report as unfetched.

The marker refusal in `_work/format.tl` is not touched, and neither is the
bootstrap advice in `skills/work/SKILL.md` — both are separate items. Note that
those items describe the two-refspec fetch as sufficient; it is sufficient for
reads, and this item is what makes the write path say so plainly.

No change to `migrate6`'s own verbs, the witness format, or
`_work/snapshot_validate.tl`'s assembly of the problem list.
