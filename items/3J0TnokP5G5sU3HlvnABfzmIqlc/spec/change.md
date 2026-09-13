`new --parent ID`: when ID already carries an open `pr:`/is in `state:
review` or `state: rework` (not a bare `todo`/`plan`), filing a child
does NOT promote it to `role: container` — the item keeps its
`role: work` and its live claim/PR exactly as they were; the new child
is simply attached and stays independently pullable. The
role→container promotion remains exactly as it is today for every
other case (a plain `todo`/`plan` item gaining its first child, and the
documented reject-that-reopens-a-decision path via `verdict ... reject`
followed by `new --parent`+`drop`).
