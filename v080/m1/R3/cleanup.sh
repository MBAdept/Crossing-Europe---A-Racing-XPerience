#!/usr/bin/env bash
# R3 scratch: removes the large intermediates (user data folders, shader cache, raw pictures). The delivered pictures
# are copies in deliver/R3; the small scripts, logs and the status file stay.
set -euo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R3
rm -rf "$S/xdg" "$S/xdg_tests" "$S/xdg_mshot" "$S/xdg_inject_modern" "$S/xdg_inject_arcade" "$S/mesa" "$S/shots"
rm -f "$S"/ab/*.png "$S"/ab/*.jpg
du -sh "$S"
ls "$S" "$S/ab"
