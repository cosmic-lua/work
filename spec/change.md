Stop the sanctioned recovery from creating the second failure. Either:

- have `take` record a content-free merge-forward without making the
  recording session the head's author, so a caller can unblock a review
  without borrowing a session identity; or
- have the distance guard distinguish a session that authored the
  reviewed CONTENT from one that only recorded a merge carrying none.

Whichever is chosen, say it where a caller meets it: the descent
refusal should name the fix that does not trip the other guard, rather
than leaving "merge it forward" to be performed under whatever session
happens to be at hand.

Add cases: a caller merging forward and recording the handover leaves a
subsequent accept recordable; a session that authored real content is
still refused as it is today.
