#!/bin/bash
# scratch: A/B pictures Cycles sprite vs real-time model for the deliver folder
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-2
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/PIPE
O=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/PIPE
S=$W/assets/sprites
mkdir -p $O
python3 $D/ab.py $O/ab_baum_bauernhaus.png "--title=Cycles-Sprite (Arcade) gegen Echtzeit-Modell (Modern, Kontaktbogen-Rig, Tag)" \
	"Sprite props/tree_oak|$S/props/tree_oak.png|bg=96,140,84" \
	"Echtzeit lod0 (1220 Dreiecke)|$D/cs_props_day.png|crop=880,400,440,372" \
	"Sprite props/farmhouse|$S/props/farmhouse.png|cell=0,0,512,300|bg=96,140,84" \
	"Echtzeit lod0 (104 Dreiecke, Atlas 1024)|$D/cs_props_day.png|crop=880,0,440,372"
python3 $D/ab.py $O/ab_laterne_michel.png "--title=Cycles-Sprite (Arcade) gegen Echtzeit-Modell (Modern, Kontaktbogen-Rig, Tag)" \
	"Sprite props/streetlight|$S/props/streetlight.png|cell=0,0,192,300|bg=96,140,84" \
	"Echtzeit lod0 (312 Dreiecke)|$D/cs_props_day.png|crop=0,400,440,372" \
	"Sprite landmarks/michel|$S/landmarks/michel.png|cell=0,0,380,644|bg=96,140,84" \
	"Echtzeit lod0 (3024 Dreiecke, Atlas 2048)|$D/cs_props_day.png|crop=0,0,440,372"
python3 $D/ab.py $O/ab_limousine_showroom.png "--title=Spielerauto Limousine: Showroom-Sprite (Cycles, 160 Samples) gegen Echtzeit-Stufe show (gleiche Kamera)" \
	"Cycles-Sprite showroom/limousine|$S/showroom/limousine.png|bg=96,104,116|h=480" \
	"Echtzeit show (102314 Dreiecke)|$D/cs_limo_showroom.png|h=480"
python3 $D/ab.py $O/ab_verkehr_limousine.png "--title=Verkehr Limousine: Sprite-Zellen (Cycles, 17 Winkel) gegen Echtzeit-Modell" \
	"Sprite traffic/sedan_red (erste 8 von 17 Winkeln)|$S/traffic/sedan_red.png|crop=0,0,1136,216|bg=96,104,116|h=250" \
	"Echtzeit lod0 (17276 Dreiecke)|$D/cs_sedan_day.png|crop=0,560,440,252|h=250"
