Any change to the diff-shaped review. It stays byte-identical, as #160
guaranteed.

The `spliced_order` in-place claim (#160's review finding 1: the doc
promises tokens "stand where its splice is" and no reachable render can
observe it). Narrowing that doc comment is one line and may ride this
change, but pinning the property needs a fixture that does not exist
and is not owed here.
