Do not require GitBoard to retain a parallel template engine, or
duplicate generic parsing/scanning in GitBoard, merely to avoid
touching `cosmic.template`. Do not weaken `cosmic.template`'s
compile-time type checking or its HTML `Safe*` guarantees to add
partial rendering — any partial-render feature must be explicit,
never a global relaxation of required-field checking. Do not evaluate
inserted user/spec text as template source at any point. Do not
duplicate `«BxOU_xeG0»` (position-declared `.tmpl` build support,
already filed and explicitly waiting on real-consumer evidence) — link
build-integration friction observed here to that item instead of
re-filing it.
