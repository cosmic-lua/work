One comment edit in `_types/gentl.tl`: the erasure-rules doc comment
gains the FILE clause — primitives pass through, and so does `FILE`,
because Teal predeclares it globally (the io handle class), so keeping
it costs no declaration and erasing it would lose an honest handle
type (`search_module`'s second return). Reflow within 90 columns. No
code change; `KEEP`'s entries are untouched.
