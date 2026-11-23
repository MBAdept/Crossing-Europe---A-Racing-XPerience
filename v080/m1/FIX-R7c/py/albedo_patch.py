import json, os
os.chdir("/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-10")

p = 'scripts/race3d/builders/props.gd'
s = open(p, encoding='utf-8').read()
old_doc = """## and albedo_bias per model (albedo_bias_of(): graphics.modern.props.albedo_bias) – the colour up to that many levels
## coarser, growing from 30 to 120 m. FIX-R7c (QR7c-04): R7c put 1.25 on every model, which turned the white window frames
## of far facades grey (Nürnberg, ~100 m) for a gain measured only on the painted beams of the half-timbered houses."""
new_doc = """## and albedo_bias / albedo_bias_m per model (albedo_bias_of(): graphics.modern.props.albedo_bias) – the colour up to that
## many levels coarser, growing between the two distances. FIX-R7c (QR7c-04): R7c put 1.25 from 30 to 120 m on every
## model, which turned the white window frames of far facades grey (Nürnberg, ~100 m: 1.09 levels there). Measured
## (sparkcam, lod1, "Mittel"): without the bias the Barockhaus flickers 2.5 x its sprite at 150 m and the Grachtenhaus B
## 2.25 x – so the bias stays, but from 60 to 150 m (0.52 levels at 100 m); the half-timbered rows keep 30 to 120 m."""
assert old_doc in s
s = s.replace(old_doc, new_doc)
old_var = """var _albedo_bias: Dictionary = {}   ## "default" or model id -> mip bias of the colour far away (QR7c-04)"""
new_var = """var _albedo_bias: Dictionary = {}   ## "default" or model id -> [mip bias of the colour far away, from m, to m] (QR7c-04)"""
assert old_var in s
s = s.replace(old_var, new_var)
old_fn = """## FIX-R7c (QR7c-04): the far mip bias of a model's colour (baked.gdshader albedo_bias): its own entry of
## graphics.modern.props.albedo_bias, else "default" (0 = the atlas as sharp as near the camera).
func albedo_bias_of(model_id: String) -> float:
	return maxf(0.0, float(_albedo_bias.get(model_id, _albedo_bias.get("default", 0.0))))"""
new_fn = """## FIX-R7c (QR7c-04): the far mip bias of a model's colour (baked.gdshader albedo_bias, albedo_bias_m) as
## Vector3(levels, from m, to m): its own entry of graphics.modern.props.albedo_bias, else "default"; an entry is
## [levels, from, to] or a plain number (from 30 to 120 m). (0, …) = the atlas as sharp as near the camera.
func albedo_bias_of(model_id: String) -> Vector3:
	var v: Variant = _albedo_bias.get(model_id, _albedo_bias.get("default", 0.0))
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		return Vector3(maxf(0.0, float(a[0])), float(a[1]), maxf(float(a[1]) + 1.0, float(a[2])))
	return Vector3(maxf(0.0, float(v)), 30.0, 120.0)"""
assert old_fn in s
s = s.replace(old_fn, new_fn)
old_set = """			m.set_shader_parameter("albedo_bias", albedo_bias_of(model_id))"""
new_set = """			var ab := albedo_bias_of(model_id)
			m.set_shader_parameter("albedo_bias", ab.x)
			m.set_shader_parameter("albedo_bias_m", Vector2(ab.y, ab.z))"""
assert old_set in s
s = s.replace(old_set, new_set)
open(p, 'w', encoding='utf-8').write(s)

p = 'config/game_config.json'
s = open(p, encoding='utf-8').read()
old = '''"albedo_bias": {"default": 0.0, "props/city_german_old_fachwerk": 1.25, "props/city_german_old_fachwerk_b": 1.25}},'''
new = '''"albedo_bias": {"default": [1.25, 60.0, 150.0], "props/city_german_old_fachwerk": [1.25, 30.0, 120.0], "props/city_german_old_fachwerk_b": [1.25, 30.0, 120.0]}},'''
assert old in s
s = s.replace(old, new)
old2 = '''albedo_bias = Mip-Bias der Farbe ferner Modelle (ab 30 m wachsend, voll bei 120 m) je Modell oder default – 0 = so scharf wie nah;'''
new2 = '''albedo_bias = Mip-Bias der Farbe ferner Modelle je Modell oder default als [Stufen, von m, bis m] (wächst zwischen den beiden Entfernungen; 0 = so scharf wie nah);'''
assert old2 in s
s = s.replace(old2, new2)
json.loads(s)
open(p, 'w', encoding='utf-8').write(s)

p = 'tests/unit/race3d/test_props.gd'
s = open(p, encoding='utf-8').read()
i = s.index("## QR7c-04: the far mip bias of the colour per model")
s = s[:i] + open("/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7c/py/albedo_test.gd.txt", encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s)

p = 'docs/renderer-modern-gelaende.md'
s = open(p, encoding='utf-8').read()
old_d = """- Die Farbe der Atlanten bekommt je Modell ab 30 m einen wachsenden Mip-Bias (bis zum Wert bei 120 m, `albedo_bias`,
  `albedo_bias_m`; `graphics.modern.props.albedo_bias`: Fachwerkzeilen 1,25, sonst `default` 0) – in der Nähe bleibt sie
  so scharf wie vorher. FIX-R7c (QR7c-04): R7c setzte 1,25 auf alle Modelle; die weißen Fensterrahmen ferner Fassaden
  wurden grau (Nürnberg, ~100 m), gemessen war der Gewinn nur an den gemalten Balken des Fachwerks."""
new_d = """- Die Farbe der Atlanten bekommt je Modell einen mit der Entfernung wachsenden Mip-Bias (`albedo_bias`,
  `albedo_bias_m`; `graphics.modern.props.albedo_bias` = [Stufen, von, bis]): Fachwerkzeilen 1,25 von 30 bis 120 m,
  alle anderen (`default`) 1,25 erst von 60 bis 150 m – in der Nähe bleibt die Farbe so scharf wie vorher. FIX-R7c
  (QR7c-04): mit R7cs 1,25 ab 30 m für alle wurden die weißen Fensterrahmen ferner Fassaden grau (Nürnberg, ~100 m:
  1,09 Stufen, jetzt 0,52). Ganz ohne Bias flimmert das Barockhaus bei 150 m 2,5 × sein Sprite und das Grachtenhaus B
  2,25 × (gemessen, `sparkcam`, lod1, „Mittel“); mit 60 → 150 m: Barock 0,3 / 0,4 % bei 100 / 150 m (Sprite 0,3 / 0,4),
  Grachtenhaus B 0,4 / 0,5 % (Sprite 0,2 / 0,4), Speicher 0,2 / 0,3 % (0,2 / 0,2). Das Kontor flimmert mit und ohne Bias
  0,5 / 0,9 % (Sprite 0,1 / 0,2) – Kanten der Geometrie, nicht die Farbe (Asset-Paket)."""
assert old_d in s
s = s.replace(old_d, new_d)
open(p, 'w', encoding='utf-8').write(s)
print("ok")
