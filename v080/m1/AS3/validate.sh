#!/usr/bin/env bash
# AS3 scratch: model validator (low priority) - validate.sh [--report]
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3/env.sh
cd "$WT"
nice -n 19 python3 tools/blender/validate_models.py "$@" 2>&1
echo "exit $?"
