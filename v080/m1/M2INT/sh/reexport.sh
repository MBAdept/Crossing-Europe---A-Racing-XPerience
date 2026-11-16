#!/usr/bin/env bash
# M2INT: export the models whose intermediates are missing or changed (AS1b's props: the key of builder "building" moved
# with AS4R's hook in props_buildings.py; olive_b: own lod1 lift; bus: far plate), then ONE bake of every cached model
# ("second bake"), manifest, validator, git status. Niceness by ZS1_FERTIG. One worker.
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/M2INT
LEAD=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead
cd "$WT" || exit 1
export XDG_DATA_HOME=$S/xdg
export CE_THREADS=2
LOG=$S/logs/reexport.log
: > "$LOG"
for g in "props/farmhouse" "props/barn" "props/haybale" "props/fuel_station" "props/fuel_pump" "props/radar_camera" \
         "props/customs_booth" "props/delineator" "props/power_pylon" "props/wind_turbine" "props/streetlight" \
         "props/tree_olive_b" "traffic/bus" "landmarks/michel"; do
	NICE=19
	[ -f "$LEAD/ZS1_FERTIG" ] && NICE=10
	t0=$(date +%s)
	nice -n $NICE /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$g" --jobs=1 >> "$LOG" 2>&1
	echo "export $g exit $? ($(( $(date +%s) - t0 )) s)" | tee -a "$LOG"
done
NICE=19
[ -f "$LEAD/ZS1_FERTIG" ] && NICE=10
nice -n $NICE godot --headless --path . -s res://tools/models/bake_models.gd -- --only="*" > "$S/logs/bake_all.log" 2>&1
echo "bake all exit $?" | tee -a "$LOG"
tail -3 "$S/logs/bake_all.log" | tee -a "$LOG"
python3 tools/blender/export_models.py --manifest-only 2>&1 | tail -1 | tee -a "$LOG"
nice -n $NICE python3 tools/blender/validate_models.py --report > "$S/logs/validate_reexport.log" 2>&1
echo "validate exit $?" | tee -a "$LOG"
grep -E "CHECK|FEHLER" "$S/logs/validate_reexport.log" | tail -5 | tee -a "$LOG"
git status --short | tee -a "$LOG"
