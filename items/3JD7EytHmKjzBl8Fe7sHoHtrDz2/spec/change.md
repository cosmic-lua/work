`gitboard help bar`'s guidance on citing evidence (the paragraph
containing "A Change that names a function or a string quotes the
`grep -n` hit that places it") already requires quoting the `grep -n`
hit for a function/string citation — extend this same requirement to
every bare file:line citation of quoted source text in `## Evidence`:
the citation must pair the line number with a short, still-`grep`-able
literal string from that exact line (a distinctive substring of the
quoted text itself is sufficient — no new tooling, no new spec
section). A citation with a number but no anchor string is under the
bar the same way an unmeasured claim already is.

Update the one place this rule is documented (`gitboard help bar`) to
state it applies to file:line citations generally, not only to the
function/string-placement case it currently names, with one worked
example showing a citation before and after (a plain `:54-56` citation
next to a quote, versus the quote plus its own `grep -n` hit).
