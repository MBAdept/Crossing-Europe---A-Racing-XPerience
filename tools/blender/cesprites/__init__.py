"""Procedural sprite pipeline for Crossing Europe (Blender 5.2 as Python module).

Modules:
  meshutil   - bmesh helpers (loft, boxes, lathe, beams, decals)
  materials  - material factory; emission data for the light layers is stored on materials
  rig        - scene / camera / lighting / render passes (one Cycles scene, reused per set)
  compose    - Pillow post-processing (light-layer alpha, glow, sheets)
  vehicles   - parametric cars, vans, trucks, buses (+ police livery and light bar)
  props      - trees, buildings, roadside furniture, ferry
  icons      - small UI icons
  catalog    - every sprite set (ids, sizes, colours, cameras)
"""
