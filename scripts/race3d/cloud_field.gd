class_name CloudField
extends RefCounted
## Mode "Modern" (v0.8.0, package R7d "Freie Strecke", contract A-27): ONE cloud field for the whole picture – the sky
## (layers/backdrop.gd draws it with assets/shaders/modern/sky2d.gdshader) and the cloud shadows on the land read the
## same field, so a shadow lies under its cloud. German docs: docs/renderer-modern.md §20.
##
## The field is a layer of cloud at HEIGHT_M above the ground, fixed in the absolute world (field_pos(): the origin-
## relative position plus the sum of the floating origin's shifts) and drifting with the wind over view time (no wall
## clock, Rule 10). Its density at a field position p (metres) is the composite of three octaves of one tiling noise
## texture (texture(): r the domes – one heap per cell –, g the billows on them, b groups of heaps and clear patches):
##     n(p) = W.x · r(p / TILE_M) + W.y · g(p / TILE_M · DETAIL.x) + W.z · b(p / TILE_M · DETAIL.y)
## and a share `cover` of the sky is cloud where n exceeds threshold(cover) – a quantile of n over the texture, so
## that cover is the share of the sky that is cloud, whatever the texture. cover_for() takes it from the palette:
## Arcade's fair-weather clouds by day and at night (COVER_CLEAR, a little more in the morning and evening), a closed
## deck under rain and snow (palette "overcast" 1).
## Pure helpers and plain data; the texture is generated once per process (FastNoiseLite, seamless, fixed seeds –
## the same bytes on every run) and shared like GroundLook.noise_texture().

const SIZE := 256                      ## texels of the noise texture per side
const TILE_M := 18000.0                ## metres of field per tile of the domes (a heap every ~2.3 km)
const HEIGHT_M := 1600.0               ## height of the flat cloud base above the ground
const THICK_M := 450.0                 ## from the flat base to the highest tops (sky2d.gdshader)
const COLUMN_K := 1.6                  ## heap height² (share of THICK_M) per excess of n over the threshold, per (n_max − threshold)
const DETAIL := Vector2(2.3, 0.37)     ## scale of the billows and of the groups against the domes
const W := Vector3(0.55, 0.18, 0.27)   ## weights of the three layers (sum 1)
const COVER_CLEAR := 0.12              ## share of the field that is heap on a fair day (Arcade: 16 cumulus clusters)
const COVER_EDGE := 0.05               ## … more of it at dawn and dusk
const SOFT := 0.035                    ## half width of the cloud edge in n
const DRIFT_MS := 7.0                  ## m/s the field drifts with the wind
const WIND_DIR := Vector2(0.8, 0.6)    ## direction of the drift (x, z) – environment_rig.gd wind()
const SHADOW := 0.22                   ## display factor a thick cloud takes from the land below it by day (cloud shadows)
const QUANTILES := 64                  ## entries of the quantile table of n

static var _tex: WeakRef
static var _img: Image
static var _quant := PackedFloat32Array()


## The tiling noise texture of the field (RGBA8, mipmaps): r domes (one heap per cell), g billows, b groups, a unused.
static func texture() -> ImageTexture:
	var alive: Variant = _tex.get_ref() if _tex != null else null
	if alive is ImageTexture:
		return alive
	var tex := ImageTexture.create_from_image(image())
	_tex = weakref(tex)
	return tex


## The image of texture() (generated once per process).
static func image() -> Image:
	if _img != null:
		return _img
	# r: one dome per cell – 1 − the distance to the cell's point (cellular F1), so a cloud is a heap that is highest
	#    in its middle and the column of sky2d.gdshader gets a rounded top and a flat base
	var cells := FastNoiseLite.new()
	cells.seed = 6151
	cells.noise_type = FastNoiseLite.TYPE_CELLULAR
	cells.frequency = 0.03
	cells.cellular_jitter = 0.9
	cells.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	cells.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	cells.fractal_type = FastNoiseLite.FRACTAL_NONE
	# g: the billows on a heap's surface (the "cauliflower")
	var billows := FastNoiseLite.new()
	billows.seed = 7243
	billows.noise_type = FastNoiseLite.TYPE_PERLIN
	billows.frequency = 0.05
	billows.fractal_type = FastNoiseLite.FRACTAL_FBM
	billows.fractal_octaves = 2
	# b: large areas with more and with fewer clouds (groups of heaps, clear patches)
	var groups := FastNoiseLite.new()
	groups.seed = 8317
	groups.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	groups.frequency = 0.008
	groups.fractal_type = FastNoiseLite.FRACTAL_FBM
	groups.fractal_octaves = 2
	var layers: Array[PackedByteArray] = []
	for src: FastNoiseLite in [cells, billows, groups]:
		var im := src.get_seamless_image(SIZE, SIZE, false, false, 0.12, true)
		im.convert(Image.FORMAT_L8)
		layers.append(im.get_data())
	var bytes := PackedByteArray()
	bytes.resize(SIZE * SIZE * 4)
	for i in SIZE * SIZE:
		bytes[i * 4] = 255 - layers[0][i]
		bytes[i * 4 + 1] = layers[1][i]
		bytes[i * 4 + 2] = layers[2][i]
		bytes[i * 4 + 3] = 255
	_img = Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, bytes)
	_img.generate_mipmaps()
	return _img


## n at field position p (metres) – the shader's composite (nearest texel per octave; for tests and the cover table).
static func composite(p: Vector2) -> float:
	var img := image()
	var q := p / TILE_M
	return W.x * _texel(img, q, 0) + W.y * _texel(img, q * DETAIL.x, 1) + W.z * _texel(img, q * DETAIL.y, 2)


static func _texel(img: Image, q: Vector2, ch: int) -> float:
	var x := posmod(int(floor(q.x * SIZE)), SIZE)
	var y := posmod(int(floor(q.y * SIZE)), SIZE)
	return img.get_pixel(x, y)[ch]


## The value of n above which a share `cover` (0..1) of the field is heap: a quantile of n over one tile of the domes
## (QUANTILES entries, interpolated). cover 0 → above every n, 1 → below every n.
static func threshold(cover: float) -> float:
	_ensure_quantiles()
	var c := clampf(cover, 0.0, 1.0)
	if c <= 0.0:
		return _quant[QUANTILES] + 1.0
	if c >= 1.0:
		return _quant[0] - 1.0
	var f := (1.0 - c) * QUANTILES
	var k0 := int(floor(f))
	return lerpf(_quant[k0], _quant[mini(k0 + 1, QUANTILES)], f - k0)


## The highest n of the field (the top of the quantile table): sky2d.gdshader scales a heap's height by the excess
## over the threshold per (n_max − threshold), so the highest heaps reach THICK_M whatever the cover.
static func n_max() -> float:
	_ensure_quantiles()
	return _quant[QUANTILES]


static func _ensure_quantiles() -> void:
	if not _quant.is_empty():
		return
	var vals := PackedFloat32Array()
	var steps := 96
	for j in steps:
		for i in steps:
			vals.append(composite(Vector2((i + 0.5) / steps, (j + 0.5) / steps) * TILE_M))
	vals.sort()
	_quant.resize(QUANTILES + 1)
	for k in QUANTILES + 1:
		_quant[k] = vals[mini(vals.size() - 1, int(round(float(k) / QUANTILES * (vals.size() - 1))))]


## Share of the field that is heap for a palette (Palette.compute): COVER_CLEAR, a little more where the palette shows
## a dawn or dusk glow, a closed deck under rain and snow (overcast 1).
static func cover_for(pal: Dictionary) -> float:
	var overcast := clampf(float(pal.get("overcast", 0.0)), 0.0, 1.0)
	var glow: Variant = pal.get("glow", Color(0, 0, 0, 0))
	var edge := clampf((glow as Color).a if glow is Color else 0.0, 0.0, 1.0) * COVER_EDGE
	return lerpf(COVER_CLEAR + edge, 1.0, overcast)


## Field position (metres) of an origin-relative world position (x, z): plus the sum of the floating origin's shifts
## taken back (shift_total = the sum of every rebased(shift)) and the drift over view time t (drift()).
static func field_pos(rel_xz: Vector2, shift_total: Vector2, t: float) -> Vector2:
	return rel_xz - shift_total + drift(t)


## The drift of the field after view time t (metres): along the wind's direction (environment_rig.gd wind(): x 0.8,
## z 0.6) at DRIFT_MS, a steady speed – the wind's strength changes on bridges and with gusts, and a position that is
## speed × time would jump with it.
static func drift(t: float) -> Vector2:
	return WIND_DIR * DRIFT_MS * t


## Strength of the cloud shadows (ce_cloud.z) for a palette: SHADOW by day, none at night, under a closed deck (rain,
## snow: diffuse light) or inside a tunnel (tunnel01 1).
static func shadow_strength(pal: Dictionary, tunnel01: float) -> float:
	var day := 1.0 - smoothstep(0.1, 0.5, clampf(float(pal.get("night", 0.0)), 0.0, 1.0))
	var overcast := clampf(float(pal.get("overcast", 0.0)), 0.0, 1.0)
	return SHADOW * day * (1.0 - overcast) * (1.0 - clampf(tunnel01, 0.0, 1.0))

