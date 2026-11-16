#!/bin/bash
# scratch: the contact sheets for the deliver folder, through the tool of the repository
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-2
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/PIPE
O=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/PIPE
export XDG_DATA_HOME=$D/xdg
export MESA_SHADER_CACHE_DIR=$D/mesa
mkdir -p $O
cd $W
sheet() {
	out=$1; shift
	nice -n 10 tools/models_contact_sheet.sh $O/$out "$@" 2>&1 | grep -E "contact_sheet|ERROR|SCRIPT" | sed "s#$O/##"
}
sheet kontaktbogen_tag_alle.png --tile=440x300 --cols=5
sheet kontaktbogen_nacht_alle.png --night --tile=440x300 --cols=5
sheet kontaktbogen_tag_spielerauto.png --only="player/*" --tile=640x400 --cols=2
sheet kontaktbogen_nacht_spielerauto.png --night --only="player/*" --tile=560x300 --cols=3
sheet kontaktbogen_nacht_verkehr.png --night --only="traffic/*" --tile=560x300 --cols=3
sheet lampenkanaele.png --channels --tile=1100x170 --cols=1
ls -la $O | tail -n +2
