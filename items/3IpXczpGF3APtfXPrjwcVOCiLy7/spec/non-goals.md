- Not re-litigating the class's existence or the other sites it still
  correctly covers (13 sandbox/quicksand rows, `eDVe_UY1D`'s scope).
- Not touching the other four `map view of a declared value` rows
  (`check.tl:151`, `coverage/init.tl:92`, `coverage/init.tl:93`,
  `quicksand/box/init_test.tl:145`) — they still close by declaring the
  type; this item only moves the one stale row and corrects the one
  false claim.
- Not changing any cast, comment, or type in `cosmic/fetch/init.tl` or
  `cosmic/quicksand/box/merge.tl` — both already type-check and already
  carry a correct `-- cast:` justification; this item is classification
  and documentation only.
- Not adding a sixth class to `casts.md`'s "The floor" section, and not
  touching its 51-cast / 23-floor arithmetic — `merge.tl:135` becomes a
  documented floor SITE inside a non-floor CLASS, the same footing as
  `merge.tl:138` already has; it does not promote "map view of a
  declared value" itself into a floor class.
- Not splitting this into two items: both threads edit the same two
  files, and each of the two `casts.md` paragraph edits references facts
  the other paragraph's edit depends on (the fetch site's new class, the
  merge site's floor status) — doing only one half would leave the other
  section's cross-reference dangling.
