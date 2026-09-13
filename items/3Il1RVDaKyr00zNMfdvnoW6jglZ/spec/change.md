On a checkout with the toolchain (`make` downloads it into
`.cosmocc/`):

1. `printf 'int main(){return 0;}' > t.c; .cosmocc/*/bin/cosmocc
   -fprofile-arcs -ftest-coverage -o t t.c; ./t; ls *.gcda` — record
   the compiler output and whether a `.gcda` appears.
2. If (1) links: add a scratch `MODE=cov` block to `build/config.mk`
   modelled on `dbg` with `CONFIG_COPTS += -fprofile-arcs
   -ftest-coverage` restricted (via a per-directory override in
   `tool/net/BUILD.mk` and `third_party/lua/cosmo`'s BUILD.mk, not
   globally) to the binding sources; `make MODE=cov o/cov/tool/lua/test`;
   record whether `.gcda` files land beside the objects, and run
   `gcov` (or `.cosmocc/*/bin/x86_64-linux-cosmo-gcov`) on
   `tool/net/lsqlite3.c` to read a lines-executed percentage.
3. If (2) works, measure once per binding file and record the table
   (file, lines, covered) — that table is the first floor.
4. If either step fails, record the exact error and the nearest
   alternative: a `--coverage`-free approach such as `-fsanitize=
   coverage` with cosmopolitan's own `__sanitizer_cov_trace_pc_guard`
   hooks, or a `dbg`-mode `--ftrace` log post-processed into per-
   function hit counts (function-level, not line-level).
