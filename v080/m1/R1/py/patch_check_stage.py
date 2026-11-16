p = 'tests/race3d/check_modern_stage.gd'
s = open(p, encoding='utf-8').read()


def rep(old, new):
    global s
    assert s.count(old) == 1, (s.count(old), old[:70])
    s = s.replace(old, new)


rep('''	_need(p, not bool(_renderers.get("modern_used")) and ModernMaterials.get("_shared") == null, "Arcade nach Modern: die gemeinsamen Modern-Materialien sind fort")
	_need(p, str(arcade.get("gfx")) == "arcade" and arcade.get("renderer") is RoadRenderer, "die Etappe zeichnet der Arcade-Renderer")''',
    '''	_need(p, not bool(_renderers.get("modern_used")) and ModernMaterials._shared == null, "Arcade nach Modern: die gemeinsamen Modern-Materialien sind fort")
	_need(p, str(arcade.get("gfx")) == "arcade" and _file(arcade.get("renderer")) == "road_renderer.gd", "die Etappe zeichnet der Arcade-Renderer")''')
rep('''	out["_renderer"] = str(((sc.get("renderer") as Object).get_script() as Script).resource_path).get_file()''',
    '''	out["_renderer"] = _file(sc.get("renderer"))''')
rep('''func _parts(r: ModernRenderer, builder_id: String) -> Array:''', '''func _file(obj: Variant) -> String:
	if obj == null or not (obj is Object) or (obj as Object).get_script() == null:
		return ""
	return str(((obj as Object).get_script() as Script).resource_path).get_file()


func _parts(r: ModernRenderer, builder_id: String) -> Array:''')
open(p, 'w', encoding='utf-8').write(s)
print("ok")
