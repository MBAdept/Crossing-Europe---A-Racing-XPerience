#!/usr/bin/env bash
# R5 batch 6 (successor 4): Modern pictures of the final head where new2 predates a commit that changes them
# (B1 and Somport/U1 exit before 649be5d, the night row before 8456140), then the render check's own pictures of the
# aviation light (HUD hidden, pylon tops in the picture) and of the tunnel positions.   batch6.sh [name…]
R5=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R5
WTN=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-2
MO=$R5/tools/mo.sh
NEW_OUT=$R5/shots/new4
mkdir -p $NEW_OUT
export MO_TIMEOUT=1800
WANT=" $* "
want() { [ "$WANT" = "  " ] || [[ "$WANT" == *" $1 "* ]]; }
COMMON="--weather=normal --vehicle=limousine --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
U1X="--stage=bern_mailand --from=bern --start-km=200.3 --hour=12 --seed=16 --start-speed=120 --shot-times=2,3.5,4.5"
SOM="--stage=saragossa_pau --from=saragossa --start-km=176.3 --hour=12 --seed=4 --start-speed=100 --shot-times=2,4,6"
B1="--stage=frankfurt_koeln --from=frankfurt --start-km=185.6 --hour=12 --seed=11 --start-speed=80 --shot-times=2,4"
KBN="--stage=kiel_hamburg --from=kiel --start-km=76.4 --hour=22 --seed=11 --start-speed=80 --fuel=1 --shot-times=2,3.5,5"
want b1 && bash $MO $NEW_OUT/b1_koeln $B1 $COMMON
want somport && bash $MO $NEW_OUT/somport $SOM $COMMON
want u1_ausfahrt && bash $MO $NEW_OUT/u1_ausfahrt $U1X $COMMON
want kb_nacht2 && bash $MO $NEW_OUT/kb_nacht2 $KBN $COMMON
if want check; then
	NICE=19
	[ -e /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ] && NICE=10
	mkdir -p $R5/check5 $R5/tmp
	X=$(mktemp -d "$R5/tmp/xdg_chk.XXXXXX")
	cd $WTN || exit 1
	t0=$SECONDS
	XDG_DATA_HOME="$X" MESA_SHADER_CACHE_DIR=$R5/mesa nice -n $NICE timeout 3000 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
		--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 \
		-s res://tests/race3d/render/check_tunnel_bridge.gd -- --graphics=modern --gfx-sync --audio-sync --gfx-preset=high \
		--save=$R5/check5 > $R5/check5/check.log 2>&1
	echo "check: exit $?, $((SECONDS - t0)) s"
	rm -rf "$X"
	grep -E "RENDER-CHECK|SCRIPT ERROR" $R5/check5/check.log | cut -c1-300
fi
echo BATCH6_DONE
