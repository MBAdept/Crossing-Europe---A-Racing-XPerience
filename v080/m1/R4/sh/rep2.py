p = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R4/bericht.md'
s = open(p).read()
rep = [
('@@WETTER@@',
 'Endstand `866a74c`, Lauf von `tools/run_render_checks.sh all`: **teilchen** Regen 300 / 1.500 / 4.000 Teilchen '
 '(„Aus“ / „Steam Deck“ / „Hoch“) → 7.343 / 20.021 / 45.417 Bildpunkte, Schnee 7.872 / 17.214 / 31.645; **gischt** S1 '
 'Regen 120 km/h: „Aus“ 1 Wolke 13.556 Bildpunkte, „Mittel“ 3 Wolken 13.974; **nass** 22 Uhr 2 Spiegelungen mit 932 '
 'roten Bildpunkten, 12 Uhr Fahrbahn fern/nah 1,59 (trocken 1,17); **tunnel** Teststrecke km 51,5 Regen: Niederschlag '
 'aus, Ausblendung 0; **schneewall** N1 2.688 Dreiecke in 7 Stücken, höchstens 0,35 m'),
('| `check_night spielerauto` | **OK** (nach 1.9) – 1,06 × / 0,92 × / 0,94 × |',
 '| `check_night spielerauto` | **OK** (nach 1.9, Endstand) – Helligkeit 1,04 × / 0,93 × / 0,86 ×, Sättigung 0,95 × / 0,73 × / 0,91 × (Kompakt N1 Schnee / GT km 121 Regen / Limousine S1) |'),
('| `check_night verdeckung` | **OK** – Kuppe bei 346 m: 0 Pixel (davor bei 20 m: 38 451); Sattelzug 30 m vor Auto in 50 m: 0 Pixel (ohne Lkw 14 391), Lichtpunkt und Spiegelung |',
 '| `check_night verdeckung` | **OK** – Kuppe bei 346 m: 0 Pixel (davor bei 20 m: 38 991); Sattelzug 30 m vor Auto in 50 m: 0 Pixel (ohne Lkw 8 691), Lichtpunkt und Spiegelung |'),
]
for o, n in rep:
    assert s.count(o) == 1, o[:60]
    s = s.replace(o, n)
open(p, 'w').write(s)
print('ok')
