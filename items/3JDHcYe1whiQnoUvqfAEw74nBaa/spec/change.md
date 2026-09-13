Add `_perf/bench/json_string_bench.tl` with checked cosmic.json.decode
workloads for the proposed ASCII-string path, preserving every existing
scenario in json_bench.tl. Land this benchmark before the C optimization
so identical workload/check code runs on both sides of the comparison.
