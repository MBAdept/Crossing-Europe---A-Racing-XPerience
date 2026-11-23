#!/bin/bash
# QA-R7a: the remaining measurements after queue2 hit its time limit (one heavy job at a time, each step marked done)
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7a/sh/common.sh
mkdir -p "$S/done"
step() { [ -f "$S/done/$1" ]; }
mark() { touch "$S/done/$1"; }
echo "$(date -u +%H:%M:%S) start rest"
# perf: Saragossa – Pau mountain bends, Steam Deck preset, time scale 4, 420 s, base and R7a back to back
step perf_base || { bash "$S/sh/stage.sh" sp_deck_base base deck saragossa_pau saragossa 11 normal 4 165 420; mark perf_base; }
step perf_mine || { bash "$S/sh/stage.sh" sp_deck_mine mine deck saragossa_pau saragossa 11 normal 4 165 420; mark perf_mine; }
# night (22:00), high, and Steam Deck, day – R7a and base
step night_mine_S0 || { shot mine S0 high 22 _nacht; mark night_mine_S0; }
step night_base_S0 || { shot base S0 high 22 _nacht; mark night_base_S0; }
step deck_mine_Muenchen || { shot mine Muenchen deck; mark deck_mine_Muenchen; }
step deck_base_Muenchen || { shot base Muenchen deck; mark deck_base_Muenchen; }
step night_mine_Muenchen || { shot mine Muenchen high 22 _nacht; mark night_mine_Muenchen; }
step night_base_Muenchen || { shot base Muenchen high 22 _nacht; mark night_base_Muenchen; }
echo "$(date -u +%H:%M:%S) done rest"
