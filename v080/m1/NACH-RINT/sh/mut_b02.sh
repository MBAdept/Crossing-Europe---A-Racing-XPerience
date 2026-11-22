#!/bin/bash
# B-02 mutation check in the head worktree (run under the heavy lock; restores with git checkout)
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-RINT/sh/env.sh
cd $HEAD_W
export XDG_DATA_HOME=$S/xdg/mut
mkdir -p $XDG_DATA_HOME $S/logs/mut
run() { # name file old new
  python3 $S/sh/mut.py "$2" "$3" "$4" || return
  nice -n 10 tools/run_tests.sh test_props > $S/logs/mut/$1.log 2>&1; echo "$1 rc=$?"
  git checkout -- "$2"
  grep -E "FEHL|FAIL|multipli" $S/logs/mut/$1.log | head -6
}
nice -n 10 tools/run_tests.sh test_props > $S/logs/mut/clean.log 2>&1; echo "clean rc=$?"; tail -3 $S/logs/mut/clean.log
run baked assets/shaders/modern/baked.gdshader '	a.rgb *= v_tint;' '	a.rgb *= vec3(1.0);'
run leaves assets/shaders/modern/leaves.gdshader 'ALBEDO = t.rgb * v_bright * v_tint;' 'ALBEDO = t.rgb * v_bright;'
run board assets/shaders/modern/billboard.gdshader 'vec3 tint = COLOR.rgb * v_tint;' 'vec3 tint = COLOR.rgb;'
git status --short
