- **No change to `cosmic/_literal_format.tl` or `cosmic/literal.tl`.**
  This slice measures; the parent's other children change the encode.
  A diff that touches either file is out of scope even if it looks
  like a win.
- **No new fixture.** The existing `FLOOR` is reused as-is; do not add
  a second, larger payload to match the parent's ad-hoc 221KB one.
  Sizing the scenario for the parent's numbers is its own question and
  would change the existing floor scenarios' heap.
- **No compare-gate run as acceptance.** Adding a scenario adds a row a
  prior baseline does not have; there is nothing to compare it against
  yet. The first compare against it belongs to whichever child
  actually changes the encode.
- **No renaming or reordering of the four existing scenarios** — their
  names are the keys a stored baseline JSON is joined on.
- **`whilp/cosmopolitan` is not touched.** The C-encoder fold the
  parent names as one candidate is a separate item under the same
  parent, carrying that repo.
