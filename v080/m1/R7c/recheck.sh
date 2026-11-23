#!/usr/bin/env bash
# R7c: the two render files that were red on the old head, again on the new head
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7c/env.sh
cd "$WT"
G=$S/gates
waitmem
export XDG_DATA_HOME=$S/xdg_recheck
mkdir -p "$XDG_DATA_HOME"
nice -n 10 tools/run_render_checks.sh modern check_structures > "$G/recheck_structures.log" 2>&1
echo "structures exit $?" >> "$G/recheck_structures.log"
waitmem
nice -n 10 tools/run_render_checks.sh modern check_props_render > "$G/recheck_props.log" 2>&1
echo "props exit $?" >> "$G/recheck_props.log"
echo "$(date +%H:%M) recheck fertig" >> "$G/summary.txt"
