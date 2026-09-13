This container does not choose the final verb name or commit to JSON over
another structured encoding. It is not a performance item: the observed cost
is oversized and repeated output, not slow SQLite queries.
