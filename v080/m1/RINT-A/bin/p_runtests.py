import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new):
    s = open(path).read()
    assert s.count(old) == 1, (path, old[:70])
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'tools/run_tests.sh'
rep(p, '''	timeout 300 "$GODOT" --headless --path . -s res://tests/race/check_attract.gd -- --graphics=arcade >"$SLOG" 2>&1
	SCODE=$?
	grep -E "^CHECK" "$SLOG"
	if [ $SCODE -ne 0 ] || grep -qE "SCRIPT ERROR" "$SLOG"; then
		echo "==> Attract-Modus fehlgeschlagen"
		CODE=1
	fi
''', '''	timeout 300 "$GODOT" --headless --path . -s res://tests/race/check_attract.gd -- --graphics=arcade >"$SLOG" 2>&1
	SCODE=$?
	grep -E "^CHECK" "$SLOG"
	if [ $SCODE -ne 0 ] || grep -qE "SCRIPT ERROR" "$SLOG"; then
		echo "==> Attract-Modus fehlgeschlagen"
		CODE=1
	fi
	# … and the same in the mode "Modern" (~30 s): the demo timer starts when the scene is prepared (A-2)
	timeout 300 "$GODOT" --headless --path . -s res://tests/race/check_attract.gd -- --graphics=modern >"$SLOG" 2>&1
	SCODE=$?
	grep -E "^CHECK" "$SLOG"
	if [ $SCODE -ne 0 ] || grep -qE "SCRIPT ERROR" "$SLOG"; then
		echo "==> Attract-Modus (Modern) fehlgeschlagen"
		CODE=1
	fi
''')
rep(p, '''	timeout 300 "$GODOT" --headless --path . -s res://tests/race/check_menu_pad.gd -- --graphics=arcade >"$SLOG" 2>&1
	SCODE=$?
	grep -E "^CHECK" "$SLOG"
	if [ $SCODE -ne 0 ] || grep -qE "SCRIPT ERROR" "$SLOG"; then
		echo "==> Gamepad-Prüfung fehlgeschlagen"
		CODE=1
	fi
''', '''	timeout 300 "$GODOT" --headless --path . -s res://tests/race/check_menu_pad.gd -- --graphics=arcade >"$SLOG" 2>&1
	SCODE=$?
	grep -E "^CHECK" "$SLOG"
	if [ $SCODE -ne 0 ] || grep -qE "SCRIPT ERROR" "$SLOG"; then
		echo "==> Gamepad-Prüfung fehlgeschlagen"
		CODE=1
	fi
	# The options in two pages with real pad events (~2 s, v0.8.0 UI1): LB/RB, the quality rows dimmed in Arcade
	timeout 300 "$GODOT" --headless --path . -s res://tests/race/check_options_tabs.gd -- --graphics=arcade >"$SLOG" 2>&1
	SCODE=$?
	grep -E "^CHECK" "$SLOG"
	if [ $SCODE -ne 0 ] || grep -qE "SCRIPT ERROR" "$SLOG"; then
		echo "==> Optionen-Prüfung fehlgeschlagen"
		CODE=1
	fi
''')
rep(p, '''	timeout 600 "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/race/check_attract_scenes.gd -- --graphics=arcade >"$SLOG" 2>&1
	SCODE=$?
	grep -E "^CHECK" "$SLOG"
	if [ $SCODE -ne 0 ] || grep -qE "SCRIPT ERROR" "$SLOG"; then
		echo "==> Attract-Szenen fehlgeschlagen"
		CODE=1
	fi
''', '''	timeout 600 "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/race/check_attract_scenes.gd -- --graphics=arcade >"$SLOG" 2>&1
	SCODE=$?
	grep -E "^CHECK" "$SLOG"
	if [ $SCODE -ne 0 ] || grep -qE "SCRIPT ERROR" "$SLOG"; then
		echo "==> Attract-Szenen fehlgeschlagen"
		CODE=1
	fi
	# … and every demo scene in the mode "Modern" (same simulation: same verdicts)
	timeout 600 "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/race/check_attract_scenes.gd -- --graphics=modern >"$SLOG" 2>&1
	SCODE=$?
	grep -E "^CHECK" "$SLOG"
	if [ $SCODE -ne 0 ] || grep -qE "SCRIPT ERROR" "$SLOG"; then
		echo "==> Attract-Szenen (Modern) fehlgeschlagen"
		CODE=1
	fi
''')
print('ok')
