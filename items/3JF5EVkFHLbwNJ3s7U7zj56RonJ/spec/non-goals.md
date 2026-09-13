- Nothing reads `touches` or `access` yet. `_work/overlap.tl`'s collision
  detection and `_work/briefmeasure.tl`'s headroom table keep extracting paths
  from prose, and `_work/gitready.tl:61`
  (`local function undeclared_repos(it: item.Item, body: string): {string}`)
  keeps reading `## Access` out of the text, because no item carries the fields
  until `05-migration` fills them. `06-retire` switches the readers and deletes
  the extractors.
- No `fsck` report on dependencies here. The cycle refusal at the mutation is
  this item; D48's derived report — a `change` naming an id as blocking that is
  not in `depends_on` — needs `touches`-era prose and lands in `06-retire`.
- The board cannot be operated with these verbs until `05-migration` has run:
  `02-tree-and-fields` set the marker this build demands to `5`, and the live
  board reads `4`. Every test here runs against a fixture board
  (`_work/fixture.tl`), never the live one.
- No change to rank, to `attach`, or to how a container's role is derived. A
  waiter stays workable by doing nothing: `depends_on` is not parentage.
