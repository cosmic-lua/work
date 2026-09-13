Not changing where `*_gen.tl` output conventionally goes (`o/<stem>/`
stays the default), and not forbidding tree-writing generators as part of
this item — if that is the answer, it is a decision record, not a silent
behaviour change. Not touching `cosmic-lua/work`'s own generator, which
is a downstream consumer of whatever this settles.
