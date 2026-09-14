# Format-5 storage baseline — 2026-09-13

Read from a clone of the live board on 2026-09-13:

```
$ git for-each-ref | wc -l
3687
$ git for-each-ref refs/remotes/origin/items | wc -l
724
$ git for-each-ref refs/remotes/origin/ended | wc -l
723
$ git for-each-ref refs/remotes/origin/claim-batches | wc -l
518
$ git count-objects -vH | grep size-pack
size-pack: 20.03 MiB
$ git rev-list --count --all
31694
$ git for-each-ref --format="%(objectname)" refs/remotes/origin/items \
    refs/remotes/origin/ended refs/remotes/origin/claim-batches |
  git rev-list --count --stdin
14350
```

`--all` counts every commit this clone can reach, a second board remote
included; 14350 is the board itself — the commits on the 1965 item,
ended and claim-batch refs — and is what one branch has to carry.

Three costs follow from that shape, and together they are why the
board becomes one branch rather than a tidier set of refs.

**A whole-board write is a multi-ref push, and this environment cannot
make one.** cosmic's D49 records the measurement: the format-5
migration's one atomic push over 1425 item refs plus the marker (a
4.29 MB body) was refused by the session's egress proxy with a bare
`403`, and throwaway pushes put the cap between 50 and 100 ref updates
(1, 10 and 50 pass; 100 fail; a 6 MB body passes). It ran in **31
batches of at most 50 refs with the marker riding the last one**, the
discipline D49 sets for every whole-board rewrite. A board whose every
write touches one ref never approaches that cap; what remains is a
body-size bound the migration's staged pushes respect. This record
does not restate D49; it inherits it.

**The layout is load-bearing in 27 modules.** Every one of them names
a ref path, enumerates refs, or knows about claim batches:

```
$ grep -lE 'refs/heads/items|for_each_ref|claim-batches' _work/*.tl | grep -v _test | wc -l
27
```

**The single-head transport exists only because a multi-ref push
cannot be expressed as connector calls.** It preserves the ref layout
by archiving the commit graph as base64 packs under
`gitboard/packs/<sha256>/<chunk>.pack.b64` with a logical ref map in
`gitboard/state.literal`; every reader must import the packs and
project the refs back (`_work/singlehead_hydrate.tl`), and GitHub can
show none of it. One branch whose tree *is* the board needs no
envelope and no hydration.
