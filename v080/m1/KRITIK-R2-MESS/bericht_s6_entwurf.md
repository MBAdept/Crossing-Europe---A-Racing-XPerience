## 6. Die Hörproben, die der Nutzer jetzt hört (`deliver/AU-R/`)

Die MP3s dekodiert (ffmpeg) und an jeder Zeitmarke der .txt gesucht, wo sich das Hörbare tatsächlich ändert
(Stufe eines Bandpegels in 20-ms-Schritten, 0,3 s davor gegen 0,3 s danach; Fugen als Transienten 2,5–8 kHz; Neuheit
des Bark-Spektrums). Gemessen; ob ein Mensch eine Abweichung von 0,1 s bemerkt, ist abgeleitet (nein).

### 6.1 Zeitmarken gegen das Hörbare

| Datei | Marke (.txt) | hörbar (gemessen) | Abweichung | Merkmal |
|---|---|---|---|---|
| koehlbrandbruecke_fugen_vorher_nachher | vorher 12 Fugen 0:01.93 … 0:09.47 | 0:01.96 … 0:09.50 | alle ±0,10 s | Transienten 2,5–8 kHz (+11,8 … +13,9 dB) |
| koehlbrandbruecke_fugen_vorher_nachher | nachher 0:14.74 / 17.58 / 20.43 / 22.17 | 0:14.67 / 17.56 / 20.44 / 22.21 | −0,07 / −0,02 / +0,01 / +0,04 s | dito (+12,3 … +15,1 dB) |
| fahrt_kiel_hamburg_vorher_nachher | nachher Innenstadt 1:23.72 | 1:23.66 | −0,06 s | Pegelstufe 1–8 kHz −10,3 dB |
| fahrt_kiel_hamburg_vorher_nachher | nachher Pflaster 1:25.81 | 1:25.76–1:25.80 | −0,05 … −0,01 s | Stufe 250–1000 Hz +6,4 dB, 2,5–8 kHz +8,4 dB |
| fahrt_kiel_hamburg_vorher_nachher | nachher Asphalt 1:31.98 | 1:32.02–1:32.04 | +0,04 … +0,06 s | Stufe −6,4 / −8,4 dB |
| fahrt_kiel_hamburg_vorher_nachher | Beton (keine Marke; Bericht AU-R2: „ab 0:05 und ab 0:53“) | 0:04.9 / 0:53.4 | – | Stufe 2,5–8 kHz +3,6 / +2,2 dB |
| fahrt_kiel_hamburg_vorher_nachher | Köhlbrandbrücke 0:09.43 / 0:57.82 | 0:09.58 / 0:57.74 | +0,15 / −0,08 s | Neuheit 8,3 / 7,3 dB |
| fahrt_kiel_hamburg_vorher_nachher | vorher Innenstadt + Pflaster 0:35.86 | 0:36.00 | +0,14 s | Stufe 250–1000 Hz +4,3 dB |
| fahrt_kiel_hamburg_vorher_nachher | Bankett 0:25.77 / 1:13.87 | 0:27.26 / 1:14.94 | **+1,49 / +1,07 s** | Schotter beginnt erst, wenn das Rad das Bankett erreicht |
| fahrt_kiel_hamburg_vorher_nachher | Leitplanke 0:30.51 / 1:18.50 | 0:31.48 / 1:19.10 | **+0,97 / +0,60 s** | der Schlag kommt 0,9 s Skriptzeit nach dem Phasenbeginn |
| fahrt_kiel_hamburg_spielmix_neu | Pflaster 0:37.39 / Asphalt 0:43.64 | 0:37.38 / 0:43.68 | −0,01 / +0,04 s | Stufe 250–1000 Hz +3,9 / −2,9 dB (über 2,5 kHz verdeckt die Musik die Stufe) |
| fahrt_kiel_hamburg_spielmix_neu | Beton (keine Marke) | 0:04.6 | – | Stufe 1–8 kHz +3,6 dB |
