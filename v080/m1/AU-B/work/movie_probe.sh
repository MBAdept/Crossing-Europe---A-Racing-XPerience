#!/bin/bash
# usage: movie_probe.sh <car> [extra args after --]   -> two Movie Maker runs with --audio-sync, compares the audio tracks
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work
R=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-2
CAR=${1:-gran_turismo}
shift
OUT=$W/movie
mkdir -p "$OUT" "$W/../xdg_movie" "$W/../mesa_cache"
export XDG_DATA_HOME=$W/../xdg_movie
export MESA_SHADER_CACHE_DIR=$W/../mesa_cache
cd "$R" || exit 1
for run in a b; do
	nice -n 10 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 320x180 \
		--write-movie "$OUT/${CAR}_$run.avi" --fixed-fps 60 -s "$W/movie_probe.gd" -- --graphics=arcade --sound=modern --vehicle=$CAR "$@" 2>&1 \
		| grep -E 'movie_probe|ERROR|WARNING' | cut -c1-260
	ffmpeg -y -loglevel error -i "$OUT/${CAR}_$run.avi" -map 0:a -c:a pcm_s16le "$OUT/${CAR}_$run.wav"
	rm -f "$OUT/${CAR}_$run.avi"
done
python3 - "$OUT/${CAR}_a.wav" "$OUT/${CAR}_b.wav" <<'EOF'
import sys, wave, hashlib
import numpy as np
xs = []
for p in sys.argv[1:3]:
    with wave.open(p) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), '<i2').reshape(-1, w.getnchannels())
        xs.append(x)
        print('%s: %d Frames, %d Hz, %d Kanäle, Spitze %d, sha256 %s' % (p.split('/')[-1], len(x), w.getframerate(), w.getnchannels(), int(np.max(np.abs(x))), hashlib.sha256(x.tobytes()).hexdigest()[:16]))
n = min(len(xs[0]), len(xs[1]))
d = xs[0][:n].astype(int) - xs[1][:n].astype(int)
print('gleich lang: %s; verschiedene Abtastwerte: %d von %d; größte Abweichung %d' % (len(xs[0]) == len(xs[1]), int(np.count_nonzero(d)), d.size, int(np.max(np.abs(d))) if d.size else 0))
EOF
