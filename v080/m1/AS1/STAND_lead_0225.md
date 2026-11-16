# STAND AS1 – handover file (written by the lead after the container restart of 2026-11-11 02:25 UTC)

A predecessor agent worked on this package for about 35 minutes and was killed by a container restart.
It left NO notes of its own; this file was reconstructed by the lead from its tool log.

- Predecessor worktree (continue THERE): /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-1
- Branch: worktree-wf_bade9e46-06a-1
- Last commits:
```
2b41e16 Bauplan v0.8.0: Abschnitte 1 und 2 als ein Schub in drei Arbeitsgängen (A-8)
71b9b79 Bauplan v0.8.0: Korrekturen und Entscheidungen nach Abschnitt 0, Renderer-Fassade für Abschnitt 1
a5e4e6e v0.8.0 FIX0 (PIPE): Modellprüfer und Kontaktbogen nehmen nur einen absoluten XDG_DATA_HOME
```
- Uncommitted changes in that worktree at the restart (work in progress – review, then commit as WIP):
```
 M assets/models/manifest.json
 M assets/models/player/limousine/lod0_body.res
 M assets/models/player/limousine/model.json
 M assets/models/player/limousine/show_body.res
 M assets/models/player/limousine/wheel.res
 M tools/blender/ce3d/catalog3d.py
 M tools/blender/ce3d/decalgeo.py
 M tools/blender/ce3d/lod.py
 M tools/blender/ce3d/vehicles3d.py
 M tools/blender/cesprites/carbody.py
 M tools/blender/cesprites/cardetail.py
 M tools/models/contact_sheet.gd
?? tools/blender/ce3d/interior3d.py
```
- Scratch folder of the predecessor: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1
```
total 96
drwxr-xr-x 7 root root  4096 Nov 11 02:23 .
drwxr-xr-x 5 root root  4096 Nov 11 02:01 ..
-rwxr-xr-x 1 root root   636 Nov 11 02:04 cs.sh
-rwxr-xr-x 1 root root   845 Nov 11 02:04 ex.sh
-rw-r--r-- 1 root root   352 Nov 11 01:58 export_baseline_sedan.log
-rw-r--r-- 1 root root   171 Nov 11 02:18 geo_player_1.log
drwx------ 3 root root  4096 Nov 11 01:59 mesa
-rwxr-xr-x 1 root root   829 Nov 11 02:07 paint_exp.sh
-rw-r--r-- 1 root root 14954 Nov 11 02:15 patch_carbody.py
-rw-r--r-- 1 root root  8742 Nov 11 02:16 patch_cardetail.py
-rw-r--r-- 1 root root 10648 Nov 11 02:04 patch_cs2.py
-rw-r--r-- 1 root root  5617 Nov 11 02:21 patch_v3d_player.py
drwxr-xr-x 2 root root  4096 Nov 11 02:09 pexp
drwxr-xr-x 2 root root  4096 Nov 11 02:05 r0
drwxr-xr-x 2 root root  4096 Nov 11 02:24 r1
drwxr-xr-x 3 root root  4096 Nov 11 01:58 xdg
```

## What the predecessor did, in order (one line per tool call; the last lines are where it stopped)

1. Fast-forward worktree to wave-0 commit
2. Copy Godot import cache and run import
3. List contract headings
4. Read contract sections 1 and 2
5. Read contract section 3 decisions
6. Read contract section 4.6 models
7. Read contract file ownership and wave 1 plan
8. Read contract sections 8, 9, 10
9. Read contract section 11 amendments completely
10. Read docs/modelle.md part 1
11. Read docs/modelle.md part 2
12. List reference deliverables
13. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/FIX0/p5_kontaktbogen_tag.jpg
14. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/FIX0/p6_kontaktbogen_nacht.jpg
15. Count lines in pipeline source files
16. Read vehicles3d.py
17. Read decalgeo.py
18. Read lod.py and catalog3d.py
19. Read roles.py and core.py
20. Read export.py, manifest.py, export_models.py
21. Read cesprites/vehicles.py
22. Read cesprites/vehicles.py lines 1-260
23. Read cesprites/vehicles.py lines 260-679
24. Read cesprites/designs.py
25. Read cesprites/carbody.py part 1
26. Read cesprites/carbody.py part 2
27. Read cesprites/cardetail.py part 1
28. Read cesprites/cardetail.py part 2
29. Read cesprites/player_cars.py part 1
30. Read cesprites/player_cars.py part 2
31. Read cesprites/heavy.py
32. Read cesprites/meshutil.py
33. Read cesprites/materials.py part 1
34. Read cesprites/materials.py part 2
35. Read vpbr and glass shaders
36. Read model_factory.gd and modern_materials.gd
37. Read contact sheet tool
38. Read validate_models.py
39. Read validate_models.py lines 20-330
40. Read validate_models.py lines 330-699
41. Search for articulation conventions
42. Read vehicle rendering docs for trucks
43. Read bake_models.gd
44. Read model_db.gd part 1
45. Read sprite catalog and manifest sets
46. Read sprite catalog
47. Find tests referencing models
48. Find model-specific expectations in tests
49. Read vehicle lamp render check
50. Check for an existing export cache in the main checkout
51. Create scratch and delivery folders with short symlinks
52. Baseline export of the reference sedan (timing)
53. Baseline export of the limousine, bake, check that committed files are reproduced
54. List showroom and player sprites and manifest entries
55. /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-1/assets/sprites/showroom/limousine.png
56. /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-1/assets/sprites/showroom/kompakt.png
57. Render baseline close-up of the wave-0 limousine
58. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1/r0/limo_lod0.png
59. List function signatures of helper modules
60. Start extending the contact sheet tool (header, members)
61. Patch contact sheet: run loop and new tile lists
62. Patch contact sheet rig/render and test the chase view
63. Write /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1/patch_cs2.py
64. Apply contact sheet patch
65. Write /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1/cs.sh
66. Write /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1/ex.sh
67. Render chase views of the wave-0 limousine
68. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1/r0/limo_chase.png
69. Fix chase magnification and render the review sheet of the wave-0 limousine
70. Split the review sheet into chunks
71. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1/r0/limo_review_0.png
72. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1/r0/limo_review_1.png
73. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1/r0/limo_review_2.png
74. Look for palette light values to align the review rig with the game
75. Temporary experiment hooks for paint roughness and metal
76. Add view selection to the review mode
77. Write /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1/paint_exp.sh
78. Run the paint look experiment (6 exports and renders)
79. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1/pexp/all.png
80. Read curve helpers (round_end, stations, stroke)
81. Revert experiment hooks and print the CDT API doc
82. Restore baked models and print CDT and BVH docs
83. Write /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1/patch_carbody.py
84. Finalize and apply the carbody hook patch
85. Write /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1/patch_cardetail.py
86. Apply cardetail hook patch and read the geometry check usage
87. Add wheel_plain to DETAIL and start the sprite geometry check for player sets in the background
88. Check progress of the sprite geometry check
89. Write /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-1/tools/blender/ce3d/interior3d.py
90. Fix interior details and add hole cutting to decalgeo
91. Write /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1/patch_v3d_player.py
92. Apply player assembly patch, update detail tables, first export of the new limousine
93. Print the triangle breakdown per object of the new limousine
94. Add arch_n and gstep hooks, retune detail, re-export
95. Render review tiles of the first new limousine build
96. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1/r1/limo_a.png
97. Crop the wheel close-up for a closer look
98. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1/r1/limo_a_rad.png

## Successor: keep this file up to date from here on (done / doing now / next / pitfalls).
