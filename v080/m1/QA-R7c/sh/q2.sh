#!/bin/bash
# QA-R7c queue 2 (after q1): data scan R7c + base, unit mutations, baseline of the mutation copy
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c/sh/common.sh
until grep -q "Q1 DONE" "$S/gates/q1.out" 2>/dev/null; do sleep 30; done
echo "Q2 start $(date -u +%H:%M:%S)" >> "$S/logs/q2.out"
"$S/sh/scan.sh" "$WT" r7c all
"$S/sh/scan.sh" "$BASE" base all
python3 "$S/sh/mutate.py" U1_band_misaligned U2_nodes_always_on U3_phase_constant U4_sink_noop U5_align_noop U6_attach_not_mirrored \
	U7_far_sun_not_set U8_leaves_phase_world U10_attached_never_dropped U11_tag_override_ignored R5_cutout_bias_off R6_relief_night_off \
	>> "$S/logs/q2.out" 2>&1
echo "Q2 DONE $(date -u +%H:%M:%S)" >> "$S/logs/q2.out"
