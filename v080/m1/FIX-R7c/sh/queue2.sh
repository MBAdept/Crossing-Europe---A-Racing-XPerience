#!/bin/bash
# FIX-R7c queue 2 (after queue 1): verify the far-end narrowing (test_props, check_lod_band, mutations R7/R8), the
# countdown pictures again with it.
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7c/sh/common.sh
until grep -q "Q1 DONE" "$S/logs/queue.out" 2>/dev/null; do sleep 20; done
echo "Q2 start $(date -u +%H:%M:%S)" >> "$S/logs/queue.out"
cd "$WT" || exit 1
XDG_DATA_HOME=$S/xdg_t nice -n 10 timeout 900 tools/run_tests.sh test_props > "$S/logs/t_props3.log" 2>&1
echo "Q2 test_props exit=$? $(grep -E 'Tests, ' "$S/logs/t_props3.log")" >> "$S/logs/queue.out"
XDG_DATA_HOME=$S/xdg_rc2 nice -n 10 tools/run_render_checks.sh modern check_lod_band > "$S/logs/lodband3.log" 2>&1
echo "Q2 check_lod_band exit=$?" >> "$S/logs/queue.out"
python3 "$S/sh/mutate.py" --render R7_still_off R8_still_to_middle > "$S/logs/mut_render2.out" 2>&1
echo "Q2 mutations done" >> "$S/logs/queue.out"
rm -f "$S/shots/start_nu_deck_h12_fix"_[0-9][0-9].png
"$S/sh/pics.sh" start_deck
echo "Q2 DONE $(date -u +%H:%M:%S)" >> "$S/logs/queue.out"
