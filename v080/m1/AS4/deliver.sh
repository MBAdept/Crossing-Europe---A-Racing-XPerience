#!/usr/bin/env bash
# AS4 scratch: copies the delivery pictures with German names into deliver/AS4.
#   deliver.sh <sheet prefix> <view prefix>      e.g. deliver.sh k3 v2
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-2
K="$1"; V="$2"
mkdir -p "$D"
for g in haus kirche fabrik stadt bruecke muehle hausboot faehre; do
	for t in tag nacht; do
		[ -f "$S/sheets/${K}_${g}_${t}.png" ] && cp "$S/sheets/${K}_${g}_${t}.png" "$D/kontaktbogen_${g}_${t}.png"
	done
done
for g in land stadt bruecke schiffe; do
	for t in tag nacht; do
		src="$S/views/${V}_${g}_dist_${t}.png"
		[ -f "$src" ] || continue
		cp "$src" "$D/spielkamera_${g}_${t}.png"
		extra=""
		[ "$t" = nacht ] && extra="--night"
		# shellcheck disable=SC2086
		python3 "$S/sprite_vs.py" "$WT" "$src" "$S/views/${V}_${g}_dist_${t}.log" "$D/spielkamera_${g}_${t}_neben_sprite.png" \
			--tile=360x300 --zoom=3 $extra | tail -1
	done
	[ -f "$S/views/${V}_${g}_stufen.png" ] && cp "$S/views/${V}_${g}_stufen.png" "$D/stufenvergleich_${g}.png"
done
for f in "$S"/ab/P[123]_*_ab_[0-9][0-9].jpg; do
	[ -f "$f" ] || continue
	b=$(basename "$f" .jpg)
	IFS=_ read -r pos preset hour _ab nn <<<"$b"
	case "$pos" in
	P1) ort="kiel_hamburg_km75_8_pylone_faehren" ;;
	P2) ort="kiel_hamburg_km82_9_fachwerkportale" ;;
	P3) ort="bremen_dortmund_km1_9_fabrik_bloecke" ;;
	esac
	case "$preset" in high) q=hoch ;; medium) q=mittel ;; *) q=$preset ;; esac
	case "$hour" in 12) z=mittag ;; 195) z=daemmerung ;; *) z=$hour ;; esac
	cp "$f" "$D/ab_${ort}_${q}_${z}_${nn}.jpg"
done
ls "$D" | wc -l
