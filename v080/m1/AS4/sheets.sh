#!/usr/bin/env bash
# AS4 scratch: final contact sheets (day + night, all levels) of the AS4 models, grouped.
#   sheets.sh <prefix> [group ...]     groups: haus kirche fabrik stadt bruecke muehle hausboot faehre (default: all)
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-2
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/mesa
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR" "$S/sheets"
cd "$WT"
PREFIX="$1"; shift
GROUPS_ALL="haus kirche fabrik stadt bruecke muehle hausboot faehre"
[ $# -gt 0 ] && GROUPS_ALL="$*"
for g in $GROUPS_ALL; do
	case "$g" in
	haus) glob="props/house_med" ;;
	kirche) glob="props/church" ;;
	fabrik) glob="props/factory" ;;
	stadt) glob="props/building_*" ;;
	bruecke) glob="props/bridge_*" ;;
	muehle) glob="props/windmill" ;;
	hausboot) glob="props/houseboat" ;;
	faehre) glob="props/ferry_ship" ;;
	*) echo "unbekannte Gruppe $g"; continue ;;
	esac
	t0=$SECONDS
	nice -n 19 tools/models_contact_sheet.sh "$S/sheets/${PREFIX}_${g}_tag.png" --only="$glob" --tile=900x640 --cols=2 --lods=lod0,lod1 2>&1 | grep -E "ERROR|SCRIPT|kein" | head -3
	nice -n 19 tools/models_contact_sheet.sh "$S/sheets/${PREFIX}_${g}_nacht.png" --only="$glob" --night --tile=900x640 --cols=2 --lods=lod0,lod1 2>&1 | grep -E "ERROR|SCRIPT|kein" | head -3
	echo "$g: $((SECONDS - t0)) s"
done
echo fertig
