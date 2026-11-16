- hh noon (km 88.2 +2/+4 s, high): Modern crisper, perspective; Speicher right with plinth/turret/loading doors; gabled
  rows both sides; blank flanks visible as grazing strips (same in Arcade). Right Speicher luma Modern 76 vs Arcade 71
  (+8 %), more saturated (R 122 vs 98); left gabled in shade Modern 50 vs Arcade 63 (sun side). No brightness defect.
- nu noon (km 102.7 +2/+4 s): Modern clearly finer (barock pilasters/hoods, fachwerk timbers, flower boxes). At +4 s
  Arcade shows fachwerk_b close on the right (km ~103.6), Modern does not draw it (dropped – same as AS5a1 Hannover
  Mietshaus; renderer drop_reason, FIX-M2 B-01) -> recheck after RINT-M2.
- hn noon (km 143.9): Modern clearly finer: Gründerzeit right with quoins and shop windows with goods right beside the
  pavement; left Mietshaus/Gründerzeit crisp. Arcade sprites blurry when close.
- mu noon (München, muenchen_nuernberg from nuernberg km 161.7, +2/+4 s): LEFT SIDE EMPTY in Modern at both shots –
  Arcade shows pink Barock (model set) + vienna_zinshaus (stand-in) + yellow house; Modern draws neither model nor
  stand-in there -> props builder drop (drop_reason; bend corridor F7 strict reading per FIX-M2 B-01 which is OPEN,
  lead decision). Right Gründerzeit untinted (#f6eedc missing until R7) – reads whiter than Arcade.
- ho noon (km 81.2 +2/+4 s, Hamburg outskirts): Arcade german_house rows PINK (#e8b8a4 tint), Modern WHITE (tint for
  model instances missing until R7) – most visible difference at the Hamburg arrival. Modern houses crisper, garden
  blobs visible. Right +4 s Modern: large blank red brick flank (hanse_gabled R@15.9 km 82.0).
- Brightness (py/boxlum.py, right sunlit facades, Modern vs Arcade): Hamburg Speicher +8 %, Nürnberg +18 %,
  Hannover +13 %/+51 %, München Gründerzeit +35 % (p90 236-240); shaded left facades −20…−39 %. AS4 shop front ≈ equal.
- hh 22 high: Modern lit windows warm, irregular; lit-window pixel share Modern vs Arcade right 3.74/6.67 % (+2 s),
  5.16/5.30 % (+4 s); left 1.73/2.06, 2.14/2.49 %. Colour (235-241,186-191,53-68) vs (241-244,198-199,75-94): slightly
  more orange. Shop of AS4 lit with goods. Looks as good as Arcade, more depth.
- nu 22 high: right 4.33/4.62 % (+2 s), 2.72/5.92 % (+4 s; the near Turmhaus missing = K1); left 0.48/0.89, 1.16/3.09 %
  (Arcade shows lit facades where Modern shows the flank with blank plinth = K2).
