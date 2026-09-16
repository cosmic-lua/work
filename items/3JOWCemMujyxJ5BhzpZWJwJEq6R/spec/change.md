The bar now says "Direction, not measurement", and a refiner reading it can
reasonably conclude that naming files at all is the thing that was retired.
That would be an over-correction, and it has a cost the board has already
paid twice.

Two specs written deliberately without any file list this session each cost a
builder real time: one lost about eighty seconds to a positional caller that
a grep for the parameter name could not find, and one lost about ten minutes
to ambiguity over which template family was in scope. Neither debit traced to
a list being STALE. Both traced to having no list at all.

The distinction worth stating in `help bar`: an ILLUSTRATIVE list degrades
harmlessly — "roughly here, verify against the tree" ages into a hint that is
slightly wrong and still points the right way. A CERTIFIED locator — a line
number the bar vouches for, a match count the spec asserts — bounces a
builder when it ages, which is what #187 removed. The rule that survives both
is about what the spec CLAIMS, not about how much it says.

Say that plainly, so the next refiner reads a named file as encouraged rather
than as the retired practice, and knows the line it must not cross is
asserting the file is correct.
