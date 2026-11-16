#!/bin/bash
# scratch: is the export (generator -> GLB, textures) reproducible? Forced re-export of the models given as
# arguments, compared with the intermediates that are in the cache now (a copy of the cache is kept).
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-2
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/PIPE
C=$W/tools/blender/_cache3d
cd $W
for id in "$@"; do
	rm -rf $D/cache_keep/$id
	mkdir -p $D/cache_keep/$id
	cp -a $C/$id/. $D/cache_keep/$id/
	(cd $C/$id && md5sum model.glb *.png *.webp 2>/dev/null | sort -k2) > $D/exp_before.md5
	nice -n 10 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$id" --jobs=1 --force 2>&1 | grep -E "^EXPORT"
	(cd $C/$id && md5sum model.glb *.png *.webp 2>/dev/null | sort -k2) > $D/exp_after.md5
	if cmp -s $D/exp_before.md5 $D/exp_after.md5; then
		echo "EXPORT $id: $(wc -l < $D/exp_after.md5) Dateien byte-gleich"
	else
		echo "EXPORT $id: UNTERSCHIEDE"; diff $D/exp_before.md5 $D/exp_after.md5
	fi
done
