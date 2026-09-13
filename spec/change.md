`_cli/nilreturn.tl`: treat `macroexp` where `function` is treated in
the declaration head — it opens a body frame whose declared return is
parsed the same way, and it can lie about nil exactly like a function.
Add a fixture case to `_build/nil_returns_test.tl`'s corpus (a
module-scope `local macroexp` and a `record` method `macroexp`) that
must balance, and one lying macroexp whose `return nil` is counted.
Baseline unmoved (no committed site).
