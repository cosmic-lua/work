1. `3p/cosmos/cosmos_pin.tl`: version and sha lines only, per
   3ITnbooy's landed procedure verbatim.
2. Baseline first on the OLD pin: `bin/cosmic --make run
   _perf/run.tl --out o/perf/oldpin.json`; then bump, `--make fetch`,
   `--make ci`; then `--make run _perf/run.tl --out
   o/perf/newpin.json` and `_perf/gate.tl compare o/perf/oldpin.json
   o/perf/newpin.json o/perf/selfb.json` — read the verdict line and
   quote it in the commit. (No `--baseline-bin` here: both files are
   measured back-to-ack in one window by the same tree build; the
   flag exists for the release lane's cross-binary case.)
3. PR with the pin diff only.
