`skills/work/SKILL.md:34-37` (cosmic-lua/cosmic): replace the bootstrap
fetch line

```
bin/gitboard sync                                       # every session
```

with

```
bin/gitboard refresh --execute                          # every session — fetches; `sync` is a deprecated no-op
```

Also grep the rest of `skills/work/SKILL.md` and `skills/work/decompose.md`
for any other bare `gitboard sync` invocation and update each the same
way; `grep -n 'gitboard sync' skills/work/SKILL.md skills/work/decompose.md`
is the sweep to confirm none are left.
