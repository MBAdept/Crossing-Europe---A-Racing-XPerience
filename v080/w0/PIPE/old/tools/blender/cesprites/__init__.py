"""Procedural sprite pipeline for Crossing Europe (Blender 5.2 as Python module).

Modules:
  meshutil   - bmesh helpers (loft, boxes, lathe, beams, decals)
  materials  - material factory; emission data for the light layers is stored on materials
  rig        - scene / camera / lighting / render passes (one Cycles scene, reused per set)
  compose    - Pillow post-processing (light-layer alpha, glow, sheets)
  vehicles   - parametric traffic cars and vans (+ police livery and light bar)
  heavy      - trucks and buses (box parts for render mode "box")
  curves     - smooth monotone splines, rounded ends, outline helpers (no bpy)
  carbody    - smooth player-car bodies (lofted analytic sections, conformal surface patches)
  cardetail  - wheels, glass, lamps, plates, exhausts, spoilers, mirrors, rails, badges
  player_cars - the five player car designs and their details
  props      - trees, buildings, roadside furniture, ferry
  icons      - small UI icons
  catalog    - every sprite set (ids, sizes, colours, cameras)
"""
