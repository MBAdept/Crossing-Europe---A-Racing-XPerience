#!/usr/bin/env bash
# QA-ZS1: overview of the first start like a player (walk/ pictures, 1280x800) -> deliver/QA-ZS1/erststart_linux_ablauf.jpg
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-ZS1
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-ZS1
W=$S/walk
T=$(mktemp -d $S/wsheet.XXXXXX)
i=0
for pair in "02_auswahl_rechts:1 GRAFIK WÄHLEN, ▶ Modern" "03_titel:2 Titel mit v0.8.0-zs1" "05_nach_enter2:3 Fahrzeug (Limousine)" \
	"08_nach_enter5:4 Etappe wird geladen" "09_rennen_11:5 Countdown in Modern" "11_pause:6 Pause"; do
	f=${pair%%:*}
	t=${pair#*:}
	convert "$W/$f.png" -resize 50% -background '#10182c' -fill white -pointsize 18 -gravity North -splice 0x28 -annotate +0+4 "$t" "$T/p$i.png"
	i=$((i + 1))
done
convert "$T/p0.png" "$T/p1.png" "$T/p2.png" +append "$T/r0.png"
convert "$T/p3.png" "$T/p4.png" "$T/p5.png" +append "$T/r1.png"
convert "$T/r0.png" "$T/r1.png" -append -quality 85 "$D/erststart_linux_ablauf.jpg"
cp "$W/09_rennen_11.png" "$T/c.png"
convert "$T/c.png" -quality 90 "$D/erststart_linux_countdown_modern_1280x800.jpg"
rm -rf "$T"
identify "$D/erststart_linux_ablauf.jpg" "$D/erststart_linux_countdown_modern_1280x800.jpg"
