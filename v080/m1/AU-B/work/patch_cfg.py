import json
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()


def rep(a, b, count=1):
    global s
    if s.count(a) != 1:
        raise SystemExit('NICHT GENAU EINMAL (%d): %s' % (s.count(a), a[:100].replace('\n', ' | ')))
    s = s.replace(a, b, count)


rep('''"levels": {"MMaster": 0.0, "MMusic": 0.0, "MSfx": -3.0, "MUI": 0.0,''', '''"levels": {"MMaster": 0.0, "MMusic": 0.0, "MSfx": 0.0, "MUI": 0.0,''')
rep('''			"engine_thread": true,
''', '''			"engine_thread": true,
			"engine": {"level_db": 0.0, "preview_db": -2.0, "preview": true, "latency_s": 0.05, "sync_latency_s": 0.07, "start_latency_s": 0.2, "buffer_s": 0.3, "motion": {"rpm": 0.0012, "level_db": 0.6, "load": 0.05, "cycle_db": 0.5, "rpm_slow": 0.003, "level_slow_db": 0.5, "load_slow": 0.07}},
			"layers": {"enabled": true, "level_db": 0.0, "turbo_db": 0.0, "driveline_db": 0.0, "shots_db": 0.0},
''')
rep('''MSfx −3 dB, solange die Platzhalter-Bausteine die Arcade-Klänge spielen (deren Vollgas liegt bei −13 LUFS).''',
    '''MSfx 0 dB, seit der Motor v3 seinen Pegel selbst mitbringt (die Banken sind so abgestimmt, dass Vollgas mit allen Buspegeln auf 0 dB bei −16 LUFS liegt; die −3 dB von Bauabschnitt 0 glichen nur die lautere Arcade-Bank aus). engine = Motor v3 (docs/motorsound.md „Modern“): level_db = Pegel des Motors zusätzlich zu mix.gain der Bank (gilt auch für die Fahrzeugebenen), preview / preview_db = Gasstoß in der Fahrzeugwahl und sein Pegel dazu, latency_s = Vorlauf, den der Mischer-Thread im Generator hält (kleiner = direktere Reaktion auf das Gas), sync_latency_s = Vorlauf beim Mischen im Hauptthread (engine_thread false oder --audio-sync), start_latency_s = dasselbe in der ersten Sekunde einer Etappe, buffer_s = Puffergröße des Generators; motion = Bewegung des Klangs, damit er nie wie eine Schleife steht, als Standardabweichungen: rpm und load relativ, level_db in dB – schnelle Unruhe –, rpm_slow, load_slow und level_slow_db – langsames Atmen über Sekunden –, cycle_db je Arbeitsspiel (0 schaltet einen Anteil ab). layers = Fahrzeugebenen auf MEngineFx (Laderton und -rauschen, Achs- und Getriebeheulen, Gasannahme, Lastwechselschlag, Schubumluft): enabled, level_db für alle, turbo_db, driveline_db und shots_db (Einmalklänge) je Gruppe dazu.''')
json.loads(s)
open(p, 'w', encoding='utf-8').write(s)
print('ok')
