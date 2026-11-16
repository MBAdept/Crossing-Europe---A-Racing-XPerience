#!/usr/bin/env bash
# cap.sh <in.png> <out-name.jpg> <caption> [max width]  -> deliver/KRITIK-5a2/<out-name.jpg> with a caption strip
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/KRITIK-5a2
mkdir -p $D
[ -f "$1" ] || { echo "fehlt: $1"; exit 1; }
w=${4:-1920}
nice -n 19 convert "$1" -resize "${w}x>" -background '#1b1f27' -fill white -font DejaVu-Sans -pointsize 22 \
	-size "$(identify -format '%w' "$1" | awk -v w=$w '{print ($1<w)?$1:w}')x" -gravity center caption:"$3" +swap -append -quality 87 "$D/$2"
echo "$2"
