#!/usr/bin/env bash
# KRITIK-4: positions of AS4 sets on representative stages (headless, nice 19), one after the other
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-4/env.sh
cd "$T"
S=props/church,props/factory,props/house_med,props/building_block_a,props/building_block_b,props/building_oldtown,props/building_shop,props/building_tall,props/bridge_lamp,props/bridge_pylon,props/bridge_truss_arch,props/houseboat,props/ferry_ship,props/windmill
run() {
	timeout 900 nice -n 19 godot --headless --path . -s res://tools/kritik/positions.gd -- --stage=$1 --from=$2 --sets=$S 2>&1 | grep -E "STAGE|km "
}
{
run dortmund_frankfurt dortmund
run kiel_hamburg hamburg
run kassel_wuerzburg kassel
run bremen_amsterdam bremen
run dresden_leipzig dresden
run paris_tours paris
run bremen_dortmund dortmund
} > "$K/logs/positions.log" 2>&1
echo POS_DONE >> "$K/logs/positions.log"
