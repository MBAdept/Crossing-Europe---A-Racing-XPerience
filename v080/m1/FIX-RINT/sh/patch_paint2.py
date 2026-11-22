import sys
W = sys.argv[1]


def patch(path, pairs):
    s = open(path).read()
    for old, new in pairs:
        assert old in s, (path, old[:70])
        s = s.replace(old, new, 1)
    open(path, 'w').write(s)


patch(W + '/scripts/race3d/modern_materials.gd', [
    ('''## FIX-RINT (QA-RINT-BILD F-06): the night share of a set whose paint R4's night law does not hold – set -> Vector2(the
## desaturation at night, the paint's value at night). The red sports car: at 22:00 in the rain (render check
## check_night "spielerauto", the red-safe body sample) 1.19 × Arcade's luminance at 1.83 × its saturation – its paint
## (#cc1419) is the most saturated of the five, the sprite's red reads dark (#924750 in the studio light). The others
## stay at 0 / 1 (kompakt 1.05 × / 1.23 ×, Gran Turismo 0.92 × / 0.77 ×, limousine 0.87–0.88 × / 0.95–1.00 ×, Kombi
## 0.86 × / 1.10 ×, measured).
const VEHICLE_PLAYER_NIGHT := {"player/sportwagen": Vector2(0.6, 0.85)}
''', '''## FIX-RINT (QA-RINT-BILD F-06): the night share of a set whose paint R4's night law does not hold – set -> Vector3(the
## desaturation at night, the paint's value at night, the share of its fill – and with it of the clear-coat sheen – at
## night). The red sports car: at 22:00 in the rain (render check check_night "spielerauto", the red-safe body sample)
## 1.19 × Arcade's luminance at 1.83 × its saturation – its paint (#cc1419) is the most saturated of the five, the
## sprite's red reads dark (#924750 in the studio light). Desaturation 0.6 alone: 0.98 × saturation but still 1.19 × –
## the brightness of the roof and boot is the night sheen of the fill, not the albedo. The others stay at 0 / 1 / 1
## (kompakt 1.05 × / 1.23 ×, Gran Turismo 0.92 × / 0.77 ×, limousine 0.87–0.88 × / 0.95–1.00 ×, Kombi 0.86 × / 1.10 ×,
## measured).
const VEHICLE_PLAYER_NIGHT := {"player/sportwagen": Vector3(0.5, 0.8, 0.45)}
'''),
    ('''	var per: Variant = VEHICLE_PLAYER_NIGHT.get(set_id)
	if per is Vector2:
		d += (per as Vector2).x * n
		value = lerpf(1.0, (per as Vector2).y, n)''', '''	var per: Variant = VEHICLE_PLAYER_NIGHT.get(set_id)
	if per is Vector3:
		d += (per as Vector3).x * n
		value = lerpf(1.0, (per as Vector3).y, n)'''),
    ('''## Clears and forgets the shared instance (leaving the mode "Modern", after ModelDB.release_all()).''', '''## FIX-RINT (F-06): the fill of a player car in a race (VEHICLE_PLAYER_FILL; a set of VEHICLE_PLAYER_NIGHT takes its
## own share of it at night, blended with the night).
static func player_fill(set_id: String, night: float = 0.0) -> float:
	var per: Variant = VEHICLE_PLAYER_NIGHT.get(set_id)
	if per is Vector3:
		return VEHICLE_PLAYER_FILL * lerpf(1.0, (per as Vector3).z, clampf(night, 0.0, 1.0))
	return VEHICLE_PLAYER_FILL


## Clears and forgets the shared instance (leaving the mode "Modern", after ModelDB.release_all()).'''),
])

patch(W + '/scripts/race3d/layers/vehicles.gd', [
    ('''			ModelFactory.apply_paint((pc as Car).node, ModernMaterials.player_paint(ModelDB.resolve((pc as Car).set_id).get("paint", {}), nt,
				(pc as Car).set_id))''', '''			ModelFactory.apply_paint((pc as Car).node, ModernMaterials.player_paint(ModelDB.resolve((pc as Car).set_id).get("paint", {}), nt,
				(pc as Car).set_id))
			# FIX-RINT (F-06): and its fill (a set of ModernMaterials.VEHICLE_PLAYER_NIGHT has its own share at night)
			var pf := ModernMaterials.player_fill((pc as Car).set_id, nt)
			for gi: GeometryInstance3D in (pc as Car).geo:
				if is_instance_valid(gi):
					gi.set_instance_shader_parameter(&"fill", pf)'''),
    ('''	var fill := PLAYER_FILL if car.id == PLAYER_ID and lod != VehicleStandIn.KIND_BOX else 0.0''',
     '''	var fill := ModernMaterials.player_fill(car.set_id, _paint_night) if car.id == PLAYER_ID and lod != VehicleStandIn.KIND_BOX else 0.0'''),
])

patch(W + '/tests/unit/race3d/test_vehicles.gd', [
    ('''	assert_eq(str(ModernMaterials.player_paint(red, 1.0, "player/limousine")["paint"]).to_lower(), "#cc1419", "ohne Eintrag nachts unverändert")
''', '''	assert_eq(str(ModernMaterials.player_paint(red, 1.0, "player/limousine")["paint"]).to_lower(), "#cc1419", "ohne Eintrag nachts unverändert")
	assert_near(ModernMaterials.player_fill("player/sportwagen", 0.0), ModernMaterials.VEHICLE_PLAYER_FILL, 1.0e-6, "Füllung bei Tag wie alle")
	assert_true(ModernMaterials.player_fill("player/sportwagen", 1.0) < ModernMaterials.VEHICLE_PLAYER_FILL * 0.6, "Sportwagen nachts weniger Füllung")
	assert_near(ModernMaterials.player_fill("player/limousine", 1.0), ModernMaterials.VEHICLE_PLAYER_FILL, 1.0e-6, "ohne Eintrag unverändert")
'''),
])
print("ok")
