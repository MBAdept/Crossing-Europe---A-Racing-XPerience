import json
p = 'config/game_config.json'
s = open(p, encoding='utf-8').read()


def rep(old, new):
    global s
    assert s.count(old) == 1, (s.count(old), old[:80])
    s = s.replace(old, new)


rep('''			"max_chunks": 16,
''', '''			"max_chunks": 18,
''')
rep('''			"sky_update_s": 2.0,
			"prewarm": true
		},''', '''			"sky_update_s": 2.0,
			"prewarm": true,
			"prepare_timeout_s": 120.0
		},''')
rep('''max_chunks (so viele Geländestücke hält der Renderer höchstens; die Laderegel will bei 900 m Sicht an 0,66 % der Kamerapositionen in Bergstrecken 17 oder 18 – dann warten die nach Luftlinie fernsten, docs/renderer-modern.md §4.1)''',
    '''max_chunks (so viele Geländestücke hält der Renderer höchstens: 18 – mit 16 fehlte bei 900 m Sicht an 0,66 % der Kamerapositionen in Bergstrecken ein Stück Straße innerhalb der Sichtweite, mit 18 nirgends im Netz, docs/renderer-modern.md §4.1)''')
rep('''sky_update_s, prewarm (Shader vor dem Start aufwärmen).''',
    '''sky_update_s (so oft höchstens wird der Himmel erneuert, der sich in Lack, Glas und nasser Fahrbahn spiegelt), prewarm (Shader vor dem Start aufwärmen), prepare_timeout_s (dauert die Vorbereitung einer Etappe länger – gezählt werden nur gezeichnete Bilder –, fährt sie im Modus „Arcade“).''')
rep('''watchdog = Langsamkeits-Wächter: countdown_min_fps (darunter senkt der Renderer im Countdown einmal die Voreinstellung), slow_factor / too_slow_factor × Bildzeit der Bildwiederholrate = „langsam“ / „zu langsam“ (Gfx.watchdog_verdict).''',
    '''watchdog = Langsamkeits-Wächter: während des Countdowns misst der Renderer die Bildzeiten und senkt die Voreinstellung für diese Etappe einmal um eine Stufe, wenn das Urteil „langsam“ lautet – slow_factor / too_slow_factor × Bildzeit der Bildwiederholrate (mindestens 1/60 s) = „langsam“ / „zu langsam“ (Gfx.watchdog_verdict) – oder die Bildrate unter countdown_min_fps liegt; aus mit --no-watchdog und im Testmodus --gfx-sync (docs/renderer-modern.md).''')
json.loads(s)
open(p, 'w', encoding='utf-8').write(s)
print("ok")
