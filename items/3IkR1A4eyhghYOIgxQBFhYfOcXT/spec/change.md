`tool/net/demo/unix-subprocess.lua`:
read the saved value's `.handler` field where the old handler is passed
back (`unix.sigaction(SIGINT, oldint.handler)`), one line per site,
nothing else. Run each demo once by hand against
`make -j$(nproc) o//tool/lua/lua` to confirm it no longer raises;
`make -j$(nproc) o//tool/lua/test` stays green.
