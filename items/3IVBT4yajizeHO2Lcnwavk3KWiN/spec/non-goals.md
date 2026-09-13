No long-string change (`ScanLongString` normalizes line endings on
purpose, per whilp/cosmopolitan#284, and that is correct). No other
escape changes. No binding contract shape change — `DecodeLua`'s
signature and error channel stand — so no `definitions.lua` change, no
type regen, no cosmic wrapper fix.
