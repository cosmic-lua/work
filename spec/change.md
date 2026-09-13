1. `3p/cosmos/cosmos_pin.tl`: version and sha lines only.
2. Baseline first on the OLD pin: `bin/cosmic --make run _perf/run.tl
   --out o/perf/oldpin.json`; then bump, `--make fetch`, `--make ci`;
   then `--make run _perf/run.tl --out o/perf/newpin.json` and
   `gate.tl compare o/perf/oldpin.json o/perf/newpin.json
   o/perf/selfb.json` — read the verdict line; quote the
   codec_base64_roundtrip_64k row in the commit.
3. PR with the pin diff only.
