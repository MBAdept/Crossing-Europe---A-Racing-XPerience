#!/usr/bin/env bash
# AS5a2: real exports of the twelve models style by style, after each style: views (close, dist) of that style.
# Detached (setsid nohup) - runs ~3 h. Progress: grep -E "STYLE|EXPORT|exit|fertig" logs/chain_real.out
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a2
source $S/env.sh
cd $WT
declare -A ST
ST[french]="props/city_french_sud props/city_french_maison props/city_french_immeuble"
ST[belgian]="props/city_belgian_terrace props/city_belgian_stone"
ST[dutch]="props/city_dutch_terrace props/city_dutch_canal props/city_dutch_canal_b"
ST[swiss]="props/city_swiss_chalet props/city_swiss_laube"
ST[paris]="props/city_paris_haussmann props/city_paris_corner"
for style in ${STYLES:-french belgian dutch swiss paris}; do
	echo "STYLE $style start $(date +%H:%M)"
	$S/real.sh ${ST[$style]}
	ids=$(echo ${ST[$style]} | sed 's#props/##g; s# #,#g')
	I=$(python3 $S/py_items.py $WT $ids)
	$S/v2.sh real_$style "$I" close dist | grep -E "exit|fertig"
	echo "STYLE $style fertig $(date +%H:%M)"
done
echo "=== chain_real fertig $(date +%H:%M)"
