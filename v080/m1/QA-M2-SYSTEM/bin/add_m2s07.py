#!/usr/bin/env python3
"""Appends finding M2S-07 (fallback text names the graphics when game files are missing) to bericht_teil_befunde.md."""
S = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM'
p = S + '/bericht_teil_befunde.md'
s = open(p).read()
if 'M2S-07' in s:
    raise SystemExit('M2S-07 schon da')
row = ('| M2S-07 | niedrig | Rückfall / Text | `scripts/race/race_session.gd` `_show_fallback_message()` (Z. 572–574; '
       'Grund in `gfx_fallback`) | Der Hinweis beim Rückfall auf Arcade nennt immer die **Grafik** („… lässt sich mit dieser '
       'Grafik nicht starten …“), auch wenn der Grund fehlende oder kaputte **Spieldateien** sind (`manifest`: Manifest fehlt, '
       'kaputtes JSON, eine Netzdatei fehlt). Der Spieler sucht dann den Fehler bei seiner Grafikkarte/seinen Treibern statt '
       'bei der Installation (z. B. unvollständiger Download, Steam „Dateien prüfen“). Der Rückfall selbst ist richtig. | '
       '`fallback/` – Log `Vorbereitung abgebrochen (manifest)` bzw. `Modus Modern nicht möglich (selftest:debug)`, im Bild '
       'derselbe Text (`rueckfall_manifest_fehlt_2s.png`, `rueckfall_modelldatei_fehlt_8s.png`; gemessen) | in einer Kopie '
       '`assets/models/manifest.json` entfernen, `--stage=kiel_hamburg --graphics=modern` starten | Den Text nach dem Grund '
       'wählen: für `manifest`/fehlende Dateien z. B. tr(„Der Modus „Modern“ lässt sich nicht starten, weil Spieldateien '
       'fehlen oder beschädigt sind. Das Spiel läuft im Modus „Arcade“ weiter.“), sonst der Text von §4.4.2; '
       '`check_seam.gd`/`check_session.gd` um den zweiten Text erweitern (Vertragsfrage V-3). |\n')
s = s.rstrip('\n') + '\n' + row
open(p, 'w').write(s)
print('ok')
