No verb's behavior changes yet — this item is transport plumbing only. Not
wiring `verdict`/`take`/any other verb to actually use the enabled transport
— that is separate sibling work, filed alongside this item under the same
decision (`f6jE_UJBu`). Not adding credential
storage, caching, or logging of the token value anywhere — it is read once,
used in-process, and never written to disk, the `o/` cache, or anything the
board pushes to its shared remote.
