Measured 2026-09-16.

A stray `gitboard new` — run as a probe of the `--` title terminator, without
realising it composes — occupied the snapshot slot. The next real verb refused:

    gitboard-done: snapshot composition belongs to gitboard; pass the same
    --session or set GITBOARD_SESSION

Nothing in that line says a junk item was pending, or how to look. It took two
further calls — `gitboard snapshot --check`, then
`git -C <board> show --stat refs/gitboard/snapshot` — to establish that the
pending composition was

    77b395aff new 3JOpng1c --a title starting with dashes
    items/3JOpng1cCEtu1snwOqrcHWOjBQF/meta | 2 ++

and a third to abandon it. Had the refusal carried the summary, the decision
would have been immediate.

The same refusal shape appeared twice more in the pass under the ordinary
cause — a `log --add` and a `new` issued while a review session held the slot —
each costing one retry with `--session` added. There the existing advice is
correct and sufficient; it is the case where the caller does NOT recognise the
owner that has no path forward but archaeology.