`sync` stays the local-only deprecated alias it is today
(`grep -n 'gitboard-sync: deprecated' _work/gitboard.tl`) — it gains no fetch.

The refusal's wording is not revised here. Once this lands the hint is
reachable by verb, and whether it should then name `gitboard refresh
--execute` instead of raw Git is a separate call.

`skills/work/SKILL.md` lives in cosmic-lua/cosmic and cannot be edited by this
PR. Its bootstrap block is its own item; landing this one makes that block
simplifiable, it does not simplify it.
