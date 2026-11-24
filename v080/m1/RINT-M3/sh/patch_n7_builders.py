import sys
W = sys.argv[1]


def sub(path, old, new, count=1):
    p = W + '/' + path
    s = open(p, encoding='utf-8').read()
    assert old in s, (path, old[:90])
    s = s.replace(old, new, count)
    open(p, 'w', encoding='utf-8').write(s)


# --- road -------------------------------------------------------------------------------------------------------------
R = 'scripts/race3d/builders/road.gd'
sub(R, '''	return {"arrays": arrays, "vertices": buf.v.size(), "triangles": buf.idx.size() / 3, "segments": rows - 1, "flags": flags_all,
		"lines_max": lines_max, "city_segments": city_segments}''', '''	# A-28 (RINT-M3): a large mesh is committed in pieces (one per step; the chunk is visible when all hang)
	return {"arrays": arrays, "vertices": buf.v.size(), "triangles": buf.idx.size() / 3, "segments": rows - 1, "flags": flags_all,
		"lines_max": lines_max, "city_segments": city_segments, "pieces": split_arrays(arrays, pieces_for(buf.v.size()))}''')
sub(R, '''func commit(_ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	if int(part.get("vertices", 0)) <= 0:
		return
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part["arrays"], [], {}, MESH_FORMAT)
	var mi := MeshInstance3D.new()
	mi.name = "Road"
	mi.mesh = mesh''', '''func commit(ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	for k in commit_steps(part):
		commit_step(ctx, part, parent, k)


## A-28 (RINT-M3): one piece of the road mesh per commit step ("Road", then "Road_2" …; one material for all).
func commit_steps(part: Dictionary) -> int:
	return maxi(1, (part.get("pieces", []) as Array).size())


func commit_step(_ctx: ChunkContext, part: Dictionary, parent: Node3D, k: int) -> void:
	if int(part.get("vertices", 0)) <= 0:
		return
	var pieces: Array = part.get("pieces", [])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, pieces[k] if k < pieces.size() else part["arrays"], [], {}, MESH_FORMAT)
	var mi := MeshInstance3D.new()
	mi.name = "Road" if k == 0 else "Road_%d" % (k + 1)
	mi.mesh = mesh''')

# --- roadside ---------------------------------------------------------------------------------------------------------
D = 'scripts/race3d/builders/roadside.gd'
sub(D, '''	return {"arrays": arrays, "vertices": buf.v.size(), "triangles": buf.idx.size() / 3, "rail_left": rail_segments[0],''',
    '''	return {"arrays": arrays, "pieces": split_arrays(arrays, pieces_for(buf.v.size())), "vertices": buf.v.size(), "triangles": buf.idx.size() / 3, "rail_left": rail_segments[0],''')
sub(D, '''func commit(ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	if int(part.get("vertices", 0)) <= 0:
		return
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part["arrays"])
	var mi := MeshInstance3D.new()
	mi.name = "Roadside"
	mi.mesh = mesh''', '''func commit(ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	for k in commit_steps(part):
		commit_step(ctx, part, parent, k)


## A-28 (RINT-M3): one piece of the mesh per commit step ("Roadside", then "Roadside_2" …); the reflectors hang on the
## first piece (all pieces are chunk-local with the identity transform).
func commit_steps(part: Dictionary) -> int:
	return maxi(1, (part.get("pieces", []) as Array).size())


func commit_step(ctx: ChunkContext, part: Dictionary, parent: Node3D, k: int) -> void:
	if int(part.get("vertices", 0)) <= 0:
		return
	var pieces: Array = part.get("pieces", [])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, pieces[k] if k < pieces.size() else part["arrays"])
	var mi := MeshInstance3D.new()
	mi.name = "Roadside" if k == 0 else "Roadside_%d" % (k + 1)
	mi.mesh = mesh''')
sub(D, '''	parent.add_child(mi)
	var renderer: Variant = ctx.services.get("renderer")
	var list: Array = part.get("reflectors", [])
	if renderer != null and not list.is_empty():''', '''	parent.add_child(mi)
	var renderer: Variant = ctx.services.get("renderer")
	var list: Array = part.get("reflectors", [])
	if k == 0 and renderer != null and not list.is_empty():''')

# --- terrain ----------------------------------------------------------------------------------------------------------
T = 'scripts/race3d/builders/terrain.gd'
sub(T, '''	return {"verts": verts, "normals": norms, "colors": cols, "uv": uvs, "uv2": uv2s, "custom": custom, "bands": bands,
		"indices": idx, "aabb": box, "rings": n, "rows": rows, "quads": quads, "water_rows": water_rows, "bank_tris": bank_tris,
		"bank_max_m": bank_top[0]}''', '''	var part := {"verts": verts, "normals": norms, "colors": cols, "uv": uvs, "uv2": uv2s, "custom": custom, "bands": bands,
		"indices": idx, "aabb": box, "rings": n, "rows": rows, "quads": quads, "water_rows": water_rows, "bank_tris": bank_tris,
		"bank_max_m": bank_top[0]}
	# A-28 (RINT-M3): a large mesh is committed in pieces (one per step; the chunk is visible when all hang)
	var np := pieces_for(verts.size())
	if np > 1:
		part["pieces"] = split_arrays(arrays_of(part), np)
	return part''')
sub(T, '''func commit(_ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	var idx: PackedInt32Array = part.get("indices", PackedInt32Array())
	if idx.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh_of(part)''', '''func commit(ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	for k in commit_steps(part):
		commit_step(ctx, part, parent, k)


## A-28 (RINT-M3): one piece of the ground per commit step ("Terrain", then "Terrain_2" …).
func commit_steps(part: Dictionary) -> int:
	return maxi(1, (part.get("pieces", []) as Array).size())


func commit_step(_ctx: ChunkContext, part: Dictionary, parent: Node3D, k: int) -> void:
	var idx: PackedInt32Array = part.get("indices", PackedInt32Array())
	if idx.is_empty():
		return
	var pieces: Array = part.get("pieces", [])
	var mi := MeshInstance3D.new()
	mi.name = "Terrain" if k == 0 else "Terrain_%d" % (k + 1)
	mi.mesh = mesh_of(part) if k >= pieces.size() else _mesh_of_arrays(pieces[k])''')
sub(T, '''## The mesh of a built part (also for tests and top views).
static func mesh_of(part: Dictionary) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = part["verts"]
	arrays[Mesh.ARRAY_NORMAL] = part["normals"]
	arrays[Mesh.ARRAY_COLOR] = part["colors"]
	arrays[Mesh.ARRAY_TEX_UV] = part["uv"]
	arrays[Mesh.ARRAY_TEX_UV2] = part["uv2"]
	arrays[Mesh.ARRAY_CUSTOM0] = part["custom"]
	arrays[Mesh.ARRAY_CUSTOM1] = part["bands"]
	arrays[Mesh.ARRAY_INDEX] = part["indices"]
	var mesh := ArrayMesh.new()''', '''## The mesh of a built part (also for tests and top views).
static func mesh_of(part: Dictionary) -> ArrayMesh:
	return _mesh_of_arrays(arrays_of(part))


## The Mesh.ARRAY_* arrays of a built part (pure, worker-safe).
static func arrays_of(part: Dictionary) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = part["verts"]
	arrays[Mesh.ARRAY_NORMAL] = part["normals"]
	arrays[Mesh.ARRAY_COLOR] = part["colors"]
	arrays[Mesh.ARRAY_TEX_UV] = part["uv"]
	arrays[Mesh.ARRAY_TEX_UV2] = part["uv2"]
	arrays[Mesh.ARRAY_CUSTOM0] = part["custom"]
	arrays[Mesh.ARRAY_CUSTOM1] = part["bands"]
	arrays[Mesh.ARRAY_INDEX] = part["indices"]
	return arrays


static func _mesh_of_arrays(arrays: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()''')
print("ok builders")
