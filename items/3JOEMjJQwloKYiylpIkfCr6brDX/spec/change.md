The spec bar stops requiring a spec to carry measurements, pasted command
output, or verified locators. A spec gives direction; the builder verifies
against the tree it actually has.

The doctrine's "Measured, not inferred" rule is the root of this. It asks
every tree-fact a spec relies on — a file's headroom, a pattern's match
count, a behavioural claim — to be written into the prose with the command
that produced it and that command's output. The intent is right: specs
asserting things from memory is a real and expensive failure mode. But the
rule writes a snapshot of the tree into a document that is read hours or
weeks later, and every one of those facts decays. A stale count, a stale
line number, a moved file, a pasted `applied` line describing a sweep that
would now do something else.

The verification it wants already happens, at the right time. `help build`
already tells a builder to re-run the spec's commands before building. That
check runs against the tree the builder has, costs seconds, and cannot be
stale. Spec-time measurement is the redundant half, and it is the half that
rots.

Change the doctrine so that:

- a spec NAMES what to change and where to look — a file, a function, an
  error string, a behaviour — as direction a builder confirms, not as a
  fact the spec certifies;
- nothing requires a pasted command, a pasted output, a match count, or a
  grep hit paired with a line citation;
- the builder's obligation to verify before building becomes the explicit
  home of that rigour, stated as such rather than implied.

Remove the sweep gap check with it. It is the only mechanical check beyond
an empty Change, and it enforces exactly the thing being dropped: it refuses
a Change mentioning a sweep flag unless dry-run output is pasted somewhere
in the prose. Delete the check and its tests; a sweep's real proof is the
builder running it.

Also drop the prescriptive lists that have the same decay: the enumeration
of wiring files a new verb or flag must name, and the requirement that a
multi-site Change state a printed match count. Say what the change is for
and let the builder find the sites.

What stays, because it does not decay: one mechanism rather than two;
imperative and concrete rather than "improve" or "investigate"; walls named
where they exist; a precondition expressed as a dependency rather than
prose; sizing; and the test that a literal-minded reader could not get it
wrong.

Say in the doctrine why the rule changed, so the next refiner does not
reintroduce it as an obvious improvement.
