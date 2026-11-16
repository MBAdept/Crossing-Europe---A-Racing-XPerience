#!/usr/bin/env bash
# R6 gates, part C in pieces: tools/run_render_checks.sh for every file, one call per filter, so that one background
# job (2 h cap) never dies in the middle of a file. Filters already done (state file) are skipped; no new filter is
# started after BUDGET_S seconds – then simply start the script again.
# Together the filters cover "run_render_checks.sh all" (2 Arcade files + every tests/race3d/render/check_*.gd).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R6
G=$S/gates
STATE=$G/rc_done.txt
BUDGET_S=${BUDGET_S:-4800}
touch "$STATE"
LIST="arcade: modern:facade_render modern:instance_budget modern:light_base modern:models modern:modern_render
modern:occlusion modern:props_render modern:quit_sound modern:road_parity modern:seam_render modern:session_modern
modern:showroom modern:start_km0 modern:structures modern:terrain_cover modern:vehicle_ modern:warmup_cold"
T0=$SECONDS
for item in $LIST; do
	grep -qxF "$item" "$STATE" && continue
	if [ $((SECONDS - T0)) -gt "$BUDGET_S" ]; then
		echo "BUDGET erreicht nach $((SECONDS - T0)) s – Rest im nächsten Lauf"
		break
	fi
	what=${item%%:*}
	filt=${item#*:}
	name="rc_${what}_${filt:-alle}"
	"$S/bin/gates_c.sh" "$what" "$filt" "$name" | grep -E "^RENDER-CHECK-DATEI|^== |^HEAD"
	echo "$item" >> "$STATE"
done
echo "erledigt: $(wc -l < "$STATE") von $(echo $LIST | wc -w)"
echo "GATES_C_LIST DONE $(date +%H:%M)"
