#!/usr/bin/env bash
# AS5aR2: cap <in.png|jpg> <out.jpg> <caption> [max width]  -> deliver folder, caption strip on top
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS5aR2
mkdir -p $D
[ -f "$1" ] || { echo "fehlt: $1"; exit 1; }
w=${4:-1920}
convert "$1" -resize "${w}x>" -background '#1b1f27' -fill white -font DejaVu-Sans -pointsize 22 \
	-gravity center label:"$3" +swap -append -quality 88 "$D/$2"
echo "$2"
