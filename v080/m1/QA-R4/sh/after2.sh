#!/bin/bash
# waits for queue2 to finish, then runs the render checks, the cold warm-up runs and the render mutations
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R4
until grep -q 'QUEUE DONE' $S/logs/queue2.log 2>/dev/null; do sleep 15; done
$S/sh/queue.sh rc_check_night rc_check_weather rc_check_vehicle_lights rc_check_start_km0 rc_check_light_base rc_check_terrain_cover \
	rc_check_occlusion rc_check_weather_tabelle rc_check_weather_tabelle_schnee w_N1_head w_N1_base w_N2N_head w_N2N_base
echo "=== $(date +%H:%M:%S) render mutations"
python3 $S/sh/mutate.py R1,R2,R3,R4
echo "=== AFTER2 DONE"
