#!/usr/bin/env bash
# M2INT: measurement queue (one heavy job at a time): showroom A/B, far-level probes (AS2R tools), olive levels,
# LOD pops (RINT-B pop probe), texture memory (Arcade vs Modern), instance census. Results in logs/meas_*.
# usage: meas.sh [step ...]   steps: showroom kritik olive pop texmem census (default all)
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/M2INT
LEAD=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead
RB=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-B/probe
D=$S/meas
mkdir -p "$D" "$S/logs"
cd "$WT" || exit 1
export XDG_DATA_HOME=$S/xdg_meas
export MESA_SHADER_CACHE_DIR=$S/mesa_cache
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
nicev() { if [ -f "$LEAD/ZS1_FERTIG" ]; then echo 10; else echo 19; fi; }
XV=(xvfb-run -a -s "-screen 0 1280x720x24")
GD=(godot --path . --rendering-driver opengl3 --audio-driver Dummy)
STEPS=("$@")
[ ${#STEPS[@]} -eq 0 ] && STEPS=(showroom kritik olive pop texmem census)
for st in "${STEPS[@]}"; do
	t0=$(date +%s)
	case "$st" in
	showroom)
		nice -n "$(nicev)" tools/models_contact_sheet.sh "$D/showroom_ab_agx.png" --showroom --tonemap=agx --only="player/*" \
			> "$S/logs/meas_showroom.log" 2>&1
		;;
	kritik)
		mkdir -p tools/kritik
		cp "$S/kritik/kritik_render.gd" "$S/kritik/kritik_dump.gd" tools/kritik/
		godot --headless --path . --import > /dev/null 2>&1
		{
			nice -n "$(nicev)" "$S/kritik/probe.sh" m2_40 40 lod0 lod1 traffic/van_white traffic/sedan_red
			nice -n "$(nicev)" "$S/kritik/probe.sh" m2_120 120 lod1 lod2 police/be traffic/suv_grey
			nice -n "$(nicev)" "$S/kritik/probe.sh" m2_60 60 lod0 lod1 traffic/bus_white
			nice -n "$(nicev)" "$S/kritik/probe.sh" m2_180 180 lod1 lod2 traffic/bus_white
			O=$S/kritik/out
			python3 "$S/kritik/bin/winmean.py" "$O/m2_40" van_white 40 lod0 lod1
			python3 "$S/kritik/bin/platemean.py" "$O/m2_40" sedan_red 40 lod0 lod1
			python3 "$S/kritik/bin/bandmean.py" "$O/m2_120" be 120 lod1 lod2
			python3 "$S/kritik/bin/buswin.py" "$O/m2_60" bus_white 60 lod0 lod1
			python3 "$S/kritik/bin/platemean.py" "$O/m2_180" bus_white 180 lod1 lod2
		} > "$S/logs/meas_kritik.log" 2>&1
		rm -rf tools/kritik
		;;
	olive)
		for h in 12 19.5 23; do
			nice -n "$(nicev)" tools/models/prop_scene.sh "$D/olive_lods_$h.png" --mode=lods --look=race --hour=$h --sprite \
				--models=props/tree_olive,props/tree_olive_b
		done > "$S/logs/meas_olive.log" 2>&1
		;;
	pop)
		for s in traffic/suv_grey traffic/sports_blue police/be traffic/bus_white; do
			timeout 900 nice -n "$(nicev)" "${XV[@]}" "${GD[@]}" --fixed-fps 60 -s "$RB/pop_probe.gd" -- --graphics=modern \
				--gfx-sync --set=$s --out="$D/pop_${s//\//_}" 2>&1 | grep -E "^POP|SCRIPT ERROR"
		done > "$S/logs/meas_pop.log" 2>&1
		;;
	popbus)
		# the bus switches lod1 -> lod2 at 180 m x vehicle_lod1_m / 120 (this machine: 90 / 120 -> 135 m)
		timeout 900 nice -n "$(nicev)" "${XV[@]}" "${GD[@]}" --fixed-fps 60 -s "$S/probe/pop_probe_lod.gd" -- --graphics=modern \
			--gfx-sync --set=traffic/bus_white --lod1=135 --out="$D/pop_traffic_bus_white" 2>&1 | grep -E "^POP|SCRIPT ERROR" \
			> "$S/logs/meas_popbus.log" 2>&1
		;;
	texmem)
		for m in arcade modern; do
			for pos in "kiel_hamburg kiel 2 12" "dortmund_frankfurt dortmund 221 19.5"; do
				set -- $pos
				timeout 900 nice -n "$(nicev)" "${XV[@]}" "${GD[@]}" -s "$S/probe/texmem_probe.gd" -- --graphics=$m --mode=$m \
					--stage=$1 --from=$2 --km=$3 --hour=$4 --secs=15 2>&1 | grep -E "^TEXMEM|SCRIPT ERROR"
			done
		done > "$S/logs/meas_texmem.log" 2>&1
		;;
	census)
		timeout 1500 nice -n "$(nicev)" "${XV[@]}" "${GD[@]}" -s "$RB/census_probe.gd" -- --graphics=modern --frames=900 \
			2>&1 | grep -E "^CENSUS|SCRIPT ERROR|PEAK|peak" | tail -12 > "$S/logs/meas_census.log"
		;;
	esac
	echo "meas $st done ($(( $(date +%s) - t0 )) s, nice $(nicev))"
done
