1. **`cosmic/quicksand/proxy/serve.tl`** — `serve_forever` becomes the
   doctrine's fallible effect:
   - `Server` record field: `serve_forever: function(): boolean, string`.
   - Body: replace `if not listen_fd then assert(listen()) end` with

     ```teal
     if not listen_fd then
       local lok, lerr = listen()
       if not lok then return false, lerr end
     end
     ```

   - The loop's normal terminations (the EBADF/EINVAL
     listener-closed return at line ~390, and any fallthrough) become
     `return true` — the "supervisor decides what next" contract is
     unchanged, it just reads as a success now.
   - The doc comment on `serve_forever` (line 5 header and the
     function's own) states the new shape: `false, err` only when the
     lazy listen fails; `true` when the accept loop ends.
2. **`cosmic/quicksand/proxy.tl:145`** — the child's cast updates to
   the new shape (`server.serve_forever as function(): (boolean,
   string)` with its existing `-- cast: function shape` reason), and
   the call checks it:

   ```teal
   local sok, serr = serve_fn()
   if not sok then
     io.stderr:write("proxy.serve: " .. tostring(serr) .. "\n")
     unix.exit(1)
   end
   unix.exit(0)
   ```

3. **`cosmic/quicksand/proxy/serve_test.tl`** — update any
   `serve_forever` use to the two-slot shape (`check.must` or an
   explicit check); re-measure the exact sites at pull.
4. No D23 edit: the record's closed list becomes TRUE by this fix
   rather than amended around; `docs/decisions/**` untouched.
