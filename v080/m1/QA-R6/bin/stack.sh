#!/usr/bin/env bash
# QA-R6: stack the A/B frames of a shot for viewing: stack.sh <name> [width]
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R6
mkdir -p $S/view
convert $S/shots/$1_ab_*.jpg -resize ${2:-1400}x -append -quality 85 $S/view/$1.jpg && echo $S/view/$1.jpg
