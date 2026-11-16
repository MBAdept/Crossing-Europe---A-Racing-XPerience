import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
rep = [
('''##                bar line of "lauf" (the ending starts at full level, the loop fades out over ending_fade_beats).''',
 '''##                bar line of "lauf" (the ending starts at full level, the loop stops within 1 ms – FADE_DISABLED).'''),
('''const ENDING_FADE_BEATS := 0.5     ## the loop fades out over this many beats under the ending's first hit
''', ''),
('''var ending_fade_beats := ENDING_FADE_BEATS
''', ''),
('''	ending_fade_beats = clampf(ctx.number("music.ending_fade_beats", ENDING_FADE_BEATS), 0.05, 4.0)
''', ''),
('''	var s := build_race_stream(main, piece.get("ending") as AudioStream if piece.get("ending") is AudioStream else null,
		ending_fade_beats)''',
 '''	var s := build_race_stream(main, piece.get("ending") as AudioStream if piece.get("ending") is AudioStream else null)'''),
('''## ending from its start at full level, the loop fading out over fade_beats (FADE_OUT). No auto-advance: measured on''',
 '''## ending from its start at full level, the loop cut within 1 ms (FADE_DISABLED: the engine's quickest fade). Any
## longer fade-out lets the loop's next downbeat sound under the ending's first hit – measured over all 88 bar lines
## of race piece 1: the first 100 ms of the ending +1.7 to +4.3 dB louder and true peaks up to +2.2 dBTP (file level)
## for fades of 1/16 to 1/2 beat, against +0.02 dB and the ending's own −2.95 dBTP with the cut, which the ending's
## downbeat masks (it starts with kick, crash and impact). No auto-advance: measured on'''),
('''static func build_race_stream(main: AudioStream, ending: AudioStream, fade_beats: float = ENDING_FADE_BEATS) -> AudioStreamInteractive:''',
 '''static func build_race_stream(main: AudioStream, ending: AudioStream) -> AudioStreamInteractive:'''),
('''			AudioStreamInteractive.TRANSITION_TO_TIME_START, AudioStreamInteractive.FADE_OUT, fade_beats)''',
 '''			AudioStreamInteractive.TRANSITION_TO_TIME_START, AudioStreamInteractive.FADE_DISABLED, 1.0)'''),
]
for a, b in rep:
    assert s.count(a) == 1, a[:70]
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
t = sys.argv[2]
s = open(t, encoding="utf-8").read()
a = '''		assert_eq(s.get_transition_fade_mode(0, 1), AudioStreamInteractive.FADE_OUT, "die Schleife blendet aus, der Schluss setzt voll ein")
		assert_near(s.get_transition_fade_beats(0, 1), MusicDirector.ENDING_FADE_BEATS, 1.0e-6, "Ausblenden in einem halben Schlag")'''
b = '''		assert_eq(s.get_transition_fade_mode(0, 1), AudioStreamInteractive.FADE_DISABLED,
			"die Schleife endet am Taktstrich (1 ms), der Schluss setzt voll ein – kein doppelter Schlag")'''
assert s.count(a) == 1
s = s.replace(a, b)
open(t, "w", encoding="utf-8").write(s)
print("ok")
