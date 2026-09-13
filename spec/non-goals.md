`_work/briefmeasure.tl`'s `change_paths`, which is a third, stricter
scanner with its own defects (level-2 only, exact case, blind to
thematic breaks). It is retired when `touches` is declared; widening it
here would be work thrown away twice.

A fence-aware scanner. A `###` inside a fenced code block is still read
as a heading after this change, exactly as before — a separate defect,
and the spec splitter that needs fence-awareness is its own item.

Deleting any of these functions. `touches` retires them later; this is
the fix for the board as it stands, because that retirement is several
items and a release away and the wrong answers are being given now.
