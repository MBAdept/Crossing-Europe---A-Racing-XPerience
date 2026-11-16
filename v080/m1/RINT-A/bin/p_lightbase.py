import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new):
    s = open(path).read()
    assert s.count(old) == 1, (path, old[:70])
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'tests/race3d/render/check_light_base.gd'
rep(p, '''##   schatten    the same view with „Schatten: Mittel“ and „Schatten: Aus“ (casters off, the flag of the light stays on
##               – D5): the mean brightness of the 3D picture below the horizon differs by at most 2 %; with „Mittel“
##               the guardrails cast shadows (pixels darker than with „Aus“), with „Aus“ nothing casts''', '''##   schatten    the same view with „Schatten: Mittel“ and „Schatten: Aus“ (casters off, the flag of the light stays on
##               – D5): LIT surfaces are equally bright in both – the mean brightness below the horizon over the pixels
##               that no shadow touches in either picture (both within SHADOW_PIXEL of each other) differs by at most
##               2 %, and those pixels are at least MIN_LIT_SHARE of the ground (a change of the base light would turn
##               most of the ground into "different" pixels). With „Mittel“ guardrails, trees, houses and the car
##               cast shadows (pixels darker than with „Aus“), with „Aus“ nothing casts. (Until the assembly of M1 the
##               check compared the mean of the whole ground; with the shadows of trees, houses and vehicles that mean
##               rightly drops by more than 2 % – D5 means equally bright lit surfaces.)''')
rep(p, '''const SHADOW_LIMIT := 0.02
''', '''const SHADOW_LIMIT := 0.02
const SHADOW_PIXEL := 0.04           ## a pixel this much darker in one picture than in the other is in a shadow
const MIN_LIT_SHARE := 0.75          ## at least this much of the ground must be lit (unshadowed) in both pictures
''')
rep(p, '''	var sum_on := 0.0
	var sum_off := 0.0
	var darker := 0
	var n := 0
	for y in range(hy + 2, on.get_height()):
		for x in range(0, on.get_width()):
			var a := on.get_pixel(x, y).get_luminance()
			var b := off.get_pixel(x, y).get_luminance()
			sum_on += a
			sum_off += b
			if a < b - 0.04:
				darker += 1
			n += 1
	var m_on := sum_on / float(maxi(n, 1))
	var m_off := sum_off / float(maxi(n, 1))
	var dev := (m_on - m_off) / maxf(m_off, 1.0e-3)
	_need(p, absf(dev) <= SHADOW_LIMIT, "mittlere Helligkeit höchstens ±2 %% verschieden (%+.2f %%)" % (dev * 100.0))
	_need(p, darker >= 100, "mit „Mittel“ sind Schatten zu sehen (%d Bildpunkte dunkler)" % darker)
	_report("schatten", p, "S1 12 Uhr: mittlere Helligkeit unter dem Horizont Mittel %.4f, Aus %.4f (%+.2f %%); %d Bildpunkte im Schatten (%.2f %% des Bodens); Schattenlicht in beiden Stufen an" % [
		m_on, m_off, dev * 100.0, darker, 100.0 * float(darker) / float(maxi(n, 1))])''', '''	var sum_on := 0.0
	var sum_off := 0.0
	var all_on := 0.0
	var all_off := 0.0
	var darker := 0
	var darker_off := 0
	var lit := 0
	var n := 0
	for y in range(hy + 2, on.get_height()):
		for x in range(0, on.get_width()):
			var a := on.get_pixel(x, y).get_luminance()
			var b := off.get_pixel(x, y).get_luminance()
			all_on += a
			all_off += b
			n += 1
			if a < b - SHADOW_PIXEL:
				darker += 1           # a real shadow with „Mittel“
			elif b < a - SHADOW_PIXEL:
				darker_off += 1       # the stronger contact shadows of „Aus“
			else:
				sum_on += a
				sum_off += b
				lit += 1
	var m_on := sum_on / float(maxi(lit, 1))
	var m_off := sum_off / float(maxi(lit, 1))
	var dev := (m_on - m_off) / maxf(m_off, 1.0e-3)
	var dev_all := (all_on - all_off) / maxf(all_off, 1.0e-3)
	var lit_share := float(lit) / float(maxi(n, 1))
	_need(p, absf(dev) <= SHADOW_LIMIT, "beleuchtete Flächen höchstens ±2 %% verschieden (%+.2f %%)" % (dev * 100.0))
	_need(p, lit_share >= MIN_LIT_SHARE, "mindestens %.0f %% des Bodens in beiden Bildern unbeschattet (%.1f %%)" % [100.0 * MIN_LIT_SHARE, 100.0 * lit_share])
	_need(p, darker >= 100, "mit „Mittel“ sind Schatten zu sehen (%d Bildpunkte dunkler)" % darker)
	_report("schatten", p, "S1 12 Uhr, beleuchtete Flächen (%.1f %% des Bodens): Mittel %.4f, Aus %.4f (%+.2f %%); ganzer Boden %+.2f %%; %d Bildpunkte im Schatten der Werfer (%.2f %%), %d mit „Aus“ dunkler (Kontaktschatten, %.2f %%); Schattenlicht in beiden Stufen an" % [
		100.0 * lit_share, m_on, m_off, dev * 100.0, dev_all * 100.0, darker, 100.0 * float(darker) / float(maxi(n, 1)), darker_off,
		100.0 * float(darker_off) / float(maxi(n, 1))])''')
print('ok')
