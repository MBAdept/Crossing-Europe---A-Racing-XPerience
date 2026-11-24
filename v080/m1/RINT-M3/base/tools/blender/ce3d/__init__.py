"""3D model pipeline of the graphics mode "Modern" (docs/modelle.md).

The procedural generators in ../cesprites stay the source of every model. This package turns their
Blender objects into the intermediates of the bake (tools/models/bake_models.gd):

  glb        own GLB writer (no bpy): nodes, meshes, vertex colours, two UV sets, named class materials
  core       triangle soups of the evaluated objects, welding, axis conversion, colour helpers
  roles      material -> material class + vertex data (paint codes, lamp channels), lamp anchors
  bake       atlas bake (weighted box unwrap, Cycles EMIT at 2x, downsample, dilation), vertex colours
  lod        generator detail levels, merged LOD meshes, shadow casters
  manifest   model.json fragments, default sets, merge to assets/models/manifest.json, budgets
  catalog3d  every model: builder, source set, LODs, colour sets
  export     one model -> _cache3d/<group>/<name>/{model.glb, model_meta.json, textures}
  vehicles3d player cars (detail levels, cabin, lamp recesses); traffic3d traffic cars; truck3d the truck;
             extras3d parts only the 3D player cars have (their cabin: cesprites.carinterior)
  decalgeo   shader decals of traffic cars -> one layer of real geometry on the body of the LOD
  veg3d      card trees (trunk + core + leaf cards) and their impostors
  leafatlas  leaf card textures
  props3d    props: vertex-PBR translation and baked buildings / landmarks

Blender space of the generators: x right, y forward (along the road), z up, metres.
Model space written here (glTF = Godot): X = x, Y = z, Z = -y; nose / far side of a prop at -Z.
"""

EXPORTER = "ce3d 1"
MANIFEST_VERSION = 1
