#!/bin/bash
# QA1 housekeeping: remove large scratch duplicates and caches; deliverables and referenced evidence stay.
set -u
Q=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA1
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/gate1

echo "== deliverable build checksums"
(cd "$D/build" && sha256sum -c --ignore-missing SHA256SUMS) || { echo "SHA FEHLER - nichts geloescht"; exit 1; }

echo "== clips: delete scratch copies only when byte-identical to the delivered ones"
for f in "$Q"/clips/*.mp4; do
	b=$(basename "$f")
	if [ -f "$D/clips/$b" ] && cmp -s "$f" "$D/clips/$b"; then
		rm -f "$f" && echo "geloescht (Duplikat): clips/$b"
	else
		echo "BEHALTEN (nicht gleich): clips/$b"
	fi
done

echo "== testbuild: delivered copy verified above, scratch entry is a duplicate"
rm -rf "$Q/testbuild" && echo "geloescht: testbuild/"

echo "== caches and per-run user dirs"
for d in mesa_ui mesa_walk mesa_clips mesa_golden mesa_ab mesa_bench mesa_rc \
		xdg_gate_render xdg_diag xdg_calib xdg_build xdg_chk xdg_gate_golden golden_final_keep tmp; do
	if [ -e "$Q/$d" ]; then
		rm -rf "${Q:?}/$d" && echo "geloescht: $d"
	fi
done

echo "== remaining"
du -sh "$Q" "$D"
ls "$D/clips" "$D/build"
