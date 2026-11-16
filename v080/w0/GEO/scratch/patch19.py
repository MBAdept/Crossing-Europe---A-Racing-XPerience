root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'
p = root + 'tests/sim/modern_path_check.gd'
s = open(p).read()
a = '''	print("PATH größte Koordinate eines Pfads ab seinem Start: %.1f km (%s) – 32-Bit-Raster dort %.1f mm ohne schwimmenden Ursprung" % [
		far_m / 1000.0, far_name, pow(2.0, floorf(log(maxf(far_m, 1.0)) / log(2.0)) - 23.0) * 1000.0])
	if full:
		_print_ribbon(ribbons)
'''
b = '''	if full:
		# only with every stage direction computed: the normal run leaves out the long, gentle ones
		print("PATH größte Koordinate eines Pfads ab seinem Start: %.1f km (%s) – 32-Bit-Raster dort %.1f mm ohne schwimmenden Ursprung" % [
			far_m / 1000.0, far_name, pow(2.0, floorf(log(maxf(far_m, 1.0)) / log(2.0)) - 23.0) * 1000.0])
		_print_ribbon(ribbons)
'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
