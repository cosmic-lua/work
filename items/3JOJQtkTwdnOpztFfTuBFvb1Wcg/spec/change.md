`docs/design/schema.md` describes machinery that no longer exists, in the
present tense.

Its schema section says the `touches` field is what `_work.overlap`'s
collision detection AND cap-headroom warnings read. The cap-headroom half is
now false: that code was removed along with the brief's measured section and
`show`'s `tight:` line, because deriving paths from prose could not tell the
files a change is about from the files it cites, and the warning duplicated
a hard gate. Collision detection is still real and still reads `touches`;
only the headroom clause is wrong.

The same document also names a function in the deleted `briefmeasure`
module that had already been renamed before that module was removed — so
that reference was stale on its own, independently of the removal.

Correct both to what is true now: `touches` feeds cross-item collision
detection, and nothing else reads it.

The section is framed as a dated historical record of a past migration,
which is why neither reference blocked anything. Decide while fixing it
whether a record written in the present tense about live code should be
reframed as history or kept current — and if kept current, whether anything
makes it stay that way, since it has now drifted twice.
