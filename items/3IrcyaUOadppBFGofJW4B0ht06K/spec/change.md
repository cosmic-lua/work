`_work/item.tl`: a one-line doc comment on the `builders` field
naming the wire-shape mismatch — that `decode` expects the field as a
space-joined string, not the in-memory array — so a reader writing a
fixture by hand sees the shape before hitting the error.
