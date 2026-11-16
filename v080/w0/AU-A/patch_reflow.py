R = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/"
p = R + "scripts/audio/modern/modern_mix.gd"
s = open(p, encoding="utf-8").read()
old = '''##                 no longer ducks the music) – scripted and the same in every run. It is not metered from the
##                 car bus: the engine offers only peak
##                 meters, and neither the peak nor the RMS of an engine sound follows its loudness (measured on
##                 the car bus with the stand-in engine, idle / 130 km/h / full throttle at −20.4 / −22.7 / −16.2
##                 LUFS: peak −6.4 / −11.1 / −0.3 dBFS, RMS −15.3 / −20.7 / −14.4 dBFS).
'''
new = '''##                 no longer ducks the music) – scripted and the same in every run. It is not metered from the
##                 car bus: the engine offers only peak meters, and neither the peak nor the RMS of an engine
##                 sound follows its loudness (measured on the car bus with the stand-in engine, idle / 130 km/h /
##                 full throttle at −20.4 / −22.7 / −16.2 LUFS: peak −6.4 / −11.1 / −0.3 dBFS, RMS −15.3 / −20.7 /
##                 −14.4 dBFS).
'''
assert s.count(old) == 1
open(p, "w", encoding="utf-8").write(s.replace(old, new))
print("ok")
