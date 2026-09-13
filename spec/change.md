Express the mechanical test in terms that hold for every repository the
board serves, not only Teal ones. A diff is mechanical when it is small
by a measure that does not assume a language — changed-line count is
already half the predicate and is language-agnostic — and when nothing it
touches is a source file the repo treats as product code.

Where the test needs to know what "product code" means for a repository,
resolve that the way the briefs already resolve repo mechanics, rather
than hard-coding a second list of extensions.

Add cases: a large diff in a repository with no Teal is NOT mechanical; a
genuinely small diff still is, in both a Teal and a non-Teal repository;
and a large diff touching only `*_test.tl` keeps whatever answer it has
today.
