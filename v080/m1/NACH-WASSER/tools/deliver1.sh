#!/usr/bin/env bash
# NACH-WASSER: pictures of queue 1 and 2 into deliver/NACH-WASSER/bilder (copies with telling names, no PNG originals).
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-WASSER
Q=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-WASSER
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/NACH-WASSER/bilder
mkdir -p "$D"
cp "$S/shots/kb_nacht_hoch_ab_01.jpg" "$D/linux_koehlbrand_nacht_hoch_km78_1_ab.jpg"
cp "$S/shots/kb_nacht_hoch_ab_02.jpg" "$D/linux_koehlbrand_nacht_hoch_km78_8_ab.jpg"
cp "$S/shots/kb_nacht_hoch_ab_03.jpg" "$D/linux_koehlbrand_nacht_hoch_km79_6_ab.jpg"
python3 -I "$S/tools/diffviz.py" "$Q/shots/kb_nacht_hoch_modern_03.png" "$S/shots/kb_nacht_hoch_modern_03.png" \
	"$D/linux_koehlbrand_nacht_km79_6_modern_alt_neu_unterschied.jpg" "Modern alter Build 0ad9012 (QA-WASSER)" "Modern gelieferter Build 39849f0"
cp "$S/crop_nacht01.jpg" "$D/linux_koehlbrand_nacht_km78_1_pylone_ausschnitt_arcade_modern.jpg"
cp "$S/shots/start_km0_ab_00.jpg" "$D/linux_start_km0_countdown_ab.jpg"
cp "$S/shots/start_km0_ab_01.jpg" "$D/linux_start_km0_los_plus_1_5s_ab.jpg"
cp "$S/shots/belgrad_ab_02.jpg" "$D/linux_belgrad_ada_km199_8_ersatzkirche_ab.jpg"
python3 -I "$S/tools/diffviz.py" "$Q/shots/ada_modern_02.png" "$S/shots/belgrad_modern_02.png" \
	"$D/linux_belgrad_km199_8_modern_alt_neu_unterschied.jpg" "Modern alter Build 0ad9012 (QA-WASSER)" "Modern gelieferter Build 39849f0"
cp "$S/shots/hannover_ab_01.jpg" "$D/linux_hannover_km147_5_ersatzkirche_ab.jpg"
cp "$S/shots/hannover_ab_02.jpg" "$D/linux_hannover_km148_2_ersatzkirche_ab.jpg"
cp "$S/shots_win/kb_nacht_hoch_ab_01.jpg" "$D/windows_wine_koehlbrand_nacht_hoch_km78_1_ab.jpg"
cp "$S/shots_win/start_km0_ab_01.jpg" "$D/windows_wine_start_km0_los_plus_1_5s_ab.jpg"
ls -la "$D"
