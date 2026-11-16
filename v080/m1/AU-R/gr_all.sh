#!/usr/bin/env bash
# AU-R: limiter gain reduction and true peak (Gesamtlautstärke 1.0) for the constant-speed captures
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R
D=${1:-$S/cap_after}
for n in asph130_full conc130_full asph200_full conc200_full vmax_full; do
	echo "== $n"
	nice -n 19 python3 "$S/ana_gr.py" "$D/$n.wav" "$D/${n}_pre.f32" | python3 -c "import json,sys; d=json.load(sys.stdin); print({k: d[k] for k in ('post_tp_at_1.0','pre_sp','gr_peak_db','samples_over_ceiling','time_reduced_s','seconds')})"
done
