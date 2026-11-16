#!/bin/bash
# QA1: second Arcade identity list (make from v0.7.0 + two checks) and the Modern change detectors (make + check).
# usage: golden_lists.sh ui|modern
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA1
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-5
G=$S/golden
mkdir -p "$G"
cd "$WT" || exit 1
export MESA_SHADER_CACHE_DIR=$S/mesa_golden
mkdir -p "$MESA_SHADER_CACHE_DIR"
case "${1:-}" in
ui)
	rm -rf "$G/ui_ref" "$G/ui_cur1" "$G/ui_cur2"
	t0=$SECONDS
	KEEP=$G/ui_ref tools/golden.sh make ui > "$G/ui_make.log" 2>&1
	echo "make ui exit=$? $((SECONDS - t0)) s"
	tail -4 "$G/ui_make.log"
	for n in 1 2; do
		t0=$SECONDS
		KEEP=$G/ui_cur$n tools/golden.sh check ui_ > "$G/ui_check$n.log" 2>&1
		echo "check ui #$n exit=$? $((SECONDS - t0)) s"
		grep -E "GOLDEN|ANDERS|fehlt|FEHLER" "$G/ui_check$n.log"
	done
	;;
modern)
	rm -rf "$G/m_make" "$G/m_check"
	t0=$SECONDS
	KEEP=$G/m_make tools/golden.sh modern-make > "$G/m_make.log" 2>&1
	echo "modern-make exit=$? $((SECONDS - t0)) s"
	tail -5 "$G/m_make.log"
	t0=$SECONDS
	KEEP=$G/m_check tools/golden.sh modern-check > "$G/m_check.log" 2>&1
	echo "modern-check exit=$? $((SECONDS - t0)) s"
	grep -E "GOLDEN|ANDERS|fehlt|FEHLER|Hinweis" "$G/m_check.log"
	;;
*)
	echo "usage: golden_lists.sh ui|modern"
	exit 2
	;;
esac
echo ALLDONE
