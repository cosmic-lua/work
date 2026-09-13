Not designing a general plugin/extension system — a fixed, four-name
make-target vocabulary covers the one non-cosmic repo in scope today and
any future one, without inventing a new manifest format or file gitboard
has to parse. Not adding a data-file config format anywhere — an earlier
version of this outcome cited `bin/cosmic.pin`/`cosmic.literal` as
precedent for "a checked-in data file gitboard reads"; that precedent
doesn't apply once the "declare mechanics" job moves to an interface (a
Makefile target) instead of a fact (a data field) — a repo answers "how
do I gate" by being able to run `make gate`, not by writing a value
down. Not moving `_work/product.tl`'s `REPO`/`BOARD_REPO` — that answers
a different question (which repo this board instance tracks, decided
once per board) and already has the isolation this outcome wants for
the axis it actually targets (how to build a given tree, which varies
per repo the board's items touch). Not migrating cosmic-lua/cosmopolitan's
own recognition today beyond adding the four Makefile targets — this
outcome makes a repo's build mechanics a fixed interface contract
instead of a hardcoded `if`/`else`, it doesn't itself add a third or
fourth repo.
