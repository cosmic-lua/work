The brief templates still instruct refiners and builders to do the thing the
spec bar just stopped asking for, so `gitboard brief refine` and `brief
research` now contradict `gitboard help bar`.

The research template tells a refiner the bar means every tree-fact a spec
names must be "measured with the command that produced it". The builder
template's first step still says to "re-run any measured commands the spec
names". The bar itself no longer asks a spec to carry measured commands at
all: it asks for direction, and the builder confirms it against the tree.

Bring the templates into line with the doctrine they quote. A refiner
following a brief should be told to give direction — what to change, where
to look, which behaviour — and a builder should be told to verify what the
spec names as a first check rather than as a repeat of one already done.

This is `refine`, `research`, `decompose` and `builder`; check `review` too,
in case it asks a reviewer to confirm pasted evidence that no longer exists.

`_work/guidance.tl` carries the same retired language in a second place, and
it is live in what `gitboard next` prints: the `pull` kind's note tells a
taker to "re-run its measured commands before building", and the `refine`
kind's note asks for "every tree-fact measured, with its command". Bring
those into line too. Their tests assert width, terseness and structure but
never content, so a regression here needs a test that would actually go red
if the retired phrasing came back.

Beyond those two modules, satisfy yourself that nothing else in the tree
still states the retired rule — two separate places drifted, so a third is
worth ruling out rather than assuming.

The brief file is near its own line cap and its tests are substantial, so
expect this to be a real change rather than a search-and-replace, and split
if the cap forces it.

While there: the templates, the guidance notes and the doctrine now say the
same thing in three places, and two of them have already drifted apart once.
Say in your report whether a template or a guidance note could quote the
doctrine topic rather than restate it, and what that would cost — do not
build it, but record the judgement so the next drift has an answer waiting.
