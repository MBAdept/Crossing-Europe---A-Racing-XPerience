#!/usr/bin/env bash
# QA-WASSER: copy the pictures for review into deliver/QA-WASSER/bilder with telling names.
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-WASSER
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-WASSER/bilder
mkdir -p "$D"
c() { [ -s "$1" ] && cp "$1" "$D/$2" && echo "$D/$2"; }
c "$S/shots/start_km0_ab_00.jpg" linux_start_km0_countdown_ab.jpg
c "$S/shots/start_km0_ab_01.jpg" linux_start_km0_los_plus_1_5s_ab.jpg
c "$S/shots/kb_tag_hoch_a_ab_00.jpg" linux_koehlbrand_tag_hoch_km77_5_ab.jpg
c "$S/shots/kb_tag_hoch_a_ab_01.jpg" linux_koehlbrand_tag_hoch_km77_7_ab.jpg
c "$S/shots/kb_tag_hoch_a_ab_02.jpg" linux_koehlbrand_tag_hoch_km78_2_ab.jpg
c "$S/shots/kb_tag_hoch_a_ab_03.jpg" linux_koehlbrand_tag_hoch_km78_7_ab.jpg
c "$S/shots/kb_tag_hoch_a_ab_04.jpg" linux_koehlbrand_tag_hoch_km79_3_ab.jpg
c "$S/shots/kb_tag_hoch_a_ab_05.jpg" linux_koehlbrand_tag_hoch_km80_0_ab.jpg
c "$S/shots/kb_tag_hoch_b_ab_00.jpg" linux_koehlbrand_tag_hoch_km79_1_ab.jpg
c "$S/shots/kb_tag_hoch_b_ab_02.jpg" linux_koehlbrand_tag_hoch_km80_2_brueckenende_ab.jpg
c "$S/shots/kb_tag_hoch_b_ab_03.jpg" linux_koehlbrand_tag_hoch_km80_9_ab.jpg
c "$S/shots/kb_nacht_hoch_ab_00.jpg" linux_koehlbrand_nacht_hoch_km77_7_ab.jpg
c "$S/shots/kb_nacht_hoch_ab_02.jpg" linux_koehlbrand_nacht_hoch_km78_8_ab.jpg
c "$S/shots/kb_nacht_hoch_ab_03.jpg" linux_koehlbrand_nacht_hoch_km79_6_ab.jpg
c "$S/shots/kb_tag_deck_ab_00.jpg" linux_koehlbrand_tag_deck_1280x800_km77_7_ab.jpg
c "$S/shots/kb_tag_deck_ab_02.jpg" linux_koehlbrand_tag_deck_1280x800_km78_8_ab.jpg
c "$S/shots/kb_nacht_deck_ab_01.jpg" linux_koehlbrand_nacht_deck_1280x800_km78_1_ab.jpg
c "$S/senk_strip_modern.jpg" linux_fernboden_sinkt_km66_8_bis_67_5_horizontstreifen_modern.jpg
c "$S/anfahrt_strip_modern.jpg" linux_anfahrt_koehlbrand_km76_5_bis_77_1_streifen_modern.jpg
c "$S/shots/kb_anfahrt_ab_05.jpg" linux_anfahrt_koehlbrand_km76_8_ab.jpg
c "$S/shots/elb_ab_01.jpg" linux_elbbruecken_km84_7_ab.jpg
c "$S/shots/holtenau_bruecke_ab_01.jpg" linux_holtenau_ab_hamburg_km85_3_ab.jpg
c "$S/shots/holtenau_bruecke_ab_02.jpg" linux_holtenau_ab_hamburg_km86_0_ab.jpg
c "$S/shots/holtenau_anfahrt_ab_00.jpg" linux_holtenau_anfahrt_km75_6_scheibe_12m_tiefer_ab.jpg
c "$S/shots/holtenau_anfahrt_ab_01.jpg" linux_holtenau_anfahrt_km76_0_scheibe_12m_tiefer_ab.jpg
c "$S/shots/ada_ab_01.jpg" linux_ada_bruecke_belgrad_km199_1_ab.jpg
c "$S/view_ada_landmark_02.jpg" linux_belgrad_wahrzeichen_fehlt_in_modern_ausschnitt.jpg
c "$S/shots/berg_t4_ab_00.jpg" linux_pyrenaeen_t4_km198_9_ab.jpg
c "$S/shots/berg_t4_ab_02.jpg" linux_pyrenaeen_t4_km200_0_ab.jpg
c "$S/view_m03_bottom.jpg" linux_koehlbrand_km78_7_pylonfuesse_modern_ausschnitt.jpg
c "$S/shots_win/wine_kb_ab_01.jpg" windows_wine_koehlbrand_km79_5_ab.jpg
c "$S/shots_win/wine_start_ab_00.jpg" windows_wine_start_km0_countdown_ab.jpg
c "$S/shots_win/wine_start_ab_01.jpg" windows_wine_start_km0_los_plus_1_5s_ab.jpg
c "$S/shots_base/senk_oldnew_viz.jpg" projekt_fernboden_sinkt_alt_neu_differenz.jpg
c "$S/shots_base/holtenau_oldnew_viz.jpg" projekt_holtenau_anfahrt_alt_neu_differenz.jpg
du -sh "$D"
