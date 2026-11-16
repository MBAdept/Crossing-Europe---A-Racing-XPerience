#!/usr/bin/env bash
# QA-R5: the music check "race" (Arcade graphics) directly, alternately on the base and the R5 head, 3 times each.
Q=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R5
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-4
for i in 1 2 3; do
	for tree in $Q/base $WT; do
		tag=$([ "$tree" = "$WT" ] && echo r5 || echo base)
		X=$(mktemp -d $Q/tmp/xdg_mp.XXXXXX)
		(cd $tree && XDG_DATA_HOME=$X nice -n 10 timeout 300 godot --headless --path . -s res://tests/unit/audio_modern/check_music.gd -- --graphics=arcade --only=race > $Q/logs/music_pair_${tag}_$i.log 2>&1)
		echo "$tag $i: $(grep -o 'CHECK race *[A-Z]*' $Q/logs/music_pair_${tag}_$i.log) $(grep -o 'längstes Bild [0-9.]* s' $Q/logs/music_pair_${tag}_$i.log) $(grep -o 'kommt [0-9.]* ms' $Q/logs/music_pair_${tag}_$i.log) $(grep -o 'erlaubt [0-9]* ms' $Q/logs/music_pair_${tag}_$i.log | head -1)"
		rm -rf $X
	done
done
