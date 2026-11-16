p = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_15398915-ab3-4/tests/unit/audio_modern/test_audio_feed.gd'
s = open(p, encoding='utf-8').read()
old = '''## On a real plan and its Track, driven in 1-m steps: a stone bridge and a tunnel of the stage in the old town – the
## stone bridge cobbled all along, the tunnel asphalt, what the car hears of the old town's streets and the stone
## bridge 0.6 ± 0.05.
func test_old_town_with_a_stone_bridge_and_a_tunnel() -> void:
	var t := _city_with_bridge("damm4", "stone_arch", 8.0, 3.0, 140.0, [{"km": 22.5, "length_km": 3.3, "name": "Elbtunnel"}])
	assert_eq(t.bridges.size(), 1, "die Steinbrücke liegt auf der Etappe")
	assert_eq(t.plan.tunnels.size(), 1, "der Tunnel liegt auf der Etappe")
	var f := _feed_with(t, {"cobble_styles": ["italian"], "cobble_share": 0.6})
	var r := _drive_old_town(f, t)
	assert_near(float(r["bridge_m"]), 140.0, 4.0, "140 m Steinbrücke in der Altstadt")
	assert_near(float(r["tunnel_m"]), 330.0, 4.0, "330 m Tunnel in der Altstadt")'''
new = '''## On a real plan and its Track, driven in 1-m steps: a stone bridge and a tunnel of the stage in the old town – the
## stone bridge cobbled all along, the tunnel asphalt, what the car hears of the old town's streets and the stone
## bridge 0.6 ± 0.05. The tunnel lies on cobbled blocks of the city (with the city's blocks this arrival would hear
## 0.42): the feed hands the plan's tunnels to the allocation and the blocks move up for this arrival only.
func test_old_town_with_a_stone_bridge_and_a_tunnel() -> void:
	var t := _city_with_bridge("damm4", "stone_arch", 8.0, 3.0, 140.0, [{"km": 23.9, "length_km": 2.5, "name": "Elbtunnel"}])
	assert_eq(t.bridges.size(), 1, "die Steinbrücke liegt auf der Etappe")
	assert_eq(t.plan.tunnels.size(), 1, "der Tunnel liegt auf der Etappe")
	var f := _feed_with(t, {"cobble_styles": ["italian"], "cobble_share": 0.6})
	var r := _drive_old_town(f, t)
	var plan: StagePlan = t.plan
	var stones := AudioFeed.stone_stretches(plan, plan.length_km, 10.0)
	var city := AudioFeed.cobbled_blocks("damm4", 800.0, 90.0, 0.6, AudioFeed.bridge_stretches(plan, plan.length_km, 10.0), stones)
	var own := AudioFeed.cobbled_blocks("damm4", 800.0, 90.0, 0.6, AudioFeed.bridge_stretches(plan, plan.length_km, 10.0), stones,
		AudioFeed.tunnel_stretches(plan, plan.length_km, 10.0))
	assert_eq(f.get("_cobbles"), own, "der Feed teilt mit den Tunneln des Plans zu")
	assert_true(own != city, "die Blöcke dieser Ankunft rücken nach")
	assert_near(float(r["bridge_m"]), 140.0, 4.0, "140 m Steinbrücke in der Altstadt")
	assert_near(float(r["tunnel_m"]), 250.0, 4.0, "250 m Tunnel in der Altstadt")'''
assert s.count(old) == 1
s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('ok')
