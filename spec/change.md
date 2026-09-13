Guard or widen each site per the library rule: never `check.must` in
library code; a `T | nil` reaching a `T` sink gets an explicit nil
branch that returns the module's failure shape, or the declaration
widens where the nil is legitimate. `cosmic/sandbox/**` only.
