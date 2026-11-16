#!/bin/bash
# b1crop.sh <nn> – Arcade | head | fix crops around the far car (x 540-740, y 180-380), 2x
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1
NN=$1
A=$S/QA-R4/shots/head/N2N_high_arcade_$NN.png
[ -f "$A" ] || A=xc:black
convert \( $A -crop 200x200+540+180 +repage -scale 200% \) \( $S/FIX-R4/shots/head_N2N_modern_$NN.png -crop 200x200+540+180 +repage -scale 200% \) \( $S/FIX-R4/shots/fix_N2N_modern_$NN.png -crop 200x200+540+180 +repage -scale 200% \) +append $S/FIX-R4/shots/b1_cmp_$NN.png
echo $S/FIX-R4/shots/b1_cmp_$NN.png
