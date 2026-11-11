extends ModernRenderer
## Test double for tests/race3d/check_facade.gd and the render checks of the skeleton: the REAL Modern renderer,
## with fixtures standing in for layers, builders and the environment rig. RaceRenderers.modern_script points here
## while a test runs; the three functions a subclass may replace are the only difference to the shipped renderer.
##   bare             true: the skeleton alone, whatever content files the renderer packages have added since –
##                    no layer file, no environment rig and no builder of scripts/race3d/ is loaded: only the debug
##                    road, the built-in plain environment and the built-in sky (plus the fixtures named below).
##                    The checks of the facade and of the skeleton's picture run bare, so they keep their meaning
##                    when builders/road.gd, layers/vehicles.gd … arrive.
##   layer_scripts    layer id -> script file that stands in for scripts/race3d/layers/<id>.gd ("" = no such layer)
##   builder_scripts  script files of extra chunk builders, registered after the others
##   rig_script       script file of the environment rig ("" = the renderer's own choice; none when bare)
##   modern_cfg       values laid over config graphics.modern of this renderer (prepare_timeout_s, prewarm, …)

static var bare := false
static var layer_scripts: Dictionary = {}
static var builder_scripts: Array[String] = []
static var rig_script := ""
static var modern_cfg: Dictionary = {}
static var instances := 0


static func reset() -> void:
	bare = false
	layer_scripts = {}
	builder_scripts = []
	rig_script = ""
	modern_cfg = {}
	instances = 0


func _init() -> void:
	instances += 1


func setup(p_track: Track, projection: RoadProjection, p_cfg: Dictionary, p_scenery_db: Dictionary) -> void:
	var own := p_cfg
	if not modern_cfg.is_empty():
		# a copy: the session's configuration stays as it is
		own = p_cfg.duplicate(true)
		var gfx: Dictionary = own.get("graphics", {})
		var modern: Dictionary = gfx.get("modern", {})
		modern.merge(modern_cfg, true)
		gfx["modern"] = modern
		own["graphics"] = gfx
	super.setup(p_track, projection, own, p_scenery_db)


func _layer_script(id: String) -> String:
	if layer_scripts.has(id):
		return str(layer_scripts[id])
	return "" if bare else super._layer_script(id)


func _create_builders() -> Array[ChunkBuilder]:
	var out: Array[ChunkBuilder] = []
	if bare:
		out.append(BuilderRegistry.create(BuilderRegistry.DEBUG_ROAD))
	else:
		out = super._create_builders()
	for script_path: String in builder_scripts:
		var b: Variant = (load(script_path) as GDScript).new()
		if b is ChunkBuilder:
			out.append(b)
	return out


func _rig_script() -> String:
	if rig_script != "":
		return rig_script
	return "" if bare else super._rig_script()
