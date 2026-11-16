#!/bin/bash
# Final offline comparisons with the committed banks, one after the other: steady-state tables (Arcade vs Modern) and
# the one-minute cruise comparison.
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work
nice -n 10 python3 "$W/e3steady.py" res://assets/audio/modern/engines "$W/s5" > "$W/steady_s5.log" 2>&1
nice -n 10 python3 "$W/e3cruise.py" "$W/cr2" > "$W/cruise_cr2.log" 2>&1
echo KETTE3 FERTIG
