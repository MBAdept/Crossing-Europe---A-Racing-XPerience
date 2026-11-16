import json
AF = "scripts/audio/modern/audio_feed.gd"
TF = "test_audio_feed.gd"
# M22b/M23b/M24b: the rules of M22/M23/M24 (KRITIK-R2-CODE) on the code of AU-R4 (the old lines are gone);
# M33-M40: the new rules of AU-R4.
extra = [
 ["M22b", AF, "cobble_block_m, cobble_share, bridge_stretches(plan, len_km, _time_scale), stone_stretches(plan, len_km, _time_scale),",
  "cobble_block_m, cobble_share, [], stone_stretches(plan, len_km, _time_scale),", TF,
  "Anteil auf den Straßen (Brücken aus der Zuteilung) – Stelle von AU-R4"],
 ["M23b", AF, "\t_closer(out, street, order, got, target, float(fit[2]))\n", "\tpass\n", TF,
  "Nachrücken ins Band 0,6 ± 0,05 – Stelle von AU-R4"],
 ["M24b", AF, "return AudioFeed.deck_of(str(b.get(\"type\", \"\"))) != \"stone\")", "return true)", TF,
  "Steinbrücken sind keine Lücke der Straße – Stelle von AU-R4"],
 ["M33", AF, "var fit := _street_fit(n, centre_m, block_m, share, _merged_stretches(skip), _merged_stretches(paved))",
  "var fit := _street_fit(n, centre_m, block_m, share, _merged_stretches(skip), [])", TF,
  "Steinbrücke als schon gepflasterte Straße (AU-R4)"],
 ["M34", AF, "\tif not late.is_empty():\n", "\tif false:\n", TF,
  "Tunnel der Etappe rückt ins Band nach (AU-R4)"],
 ["M35", AF, "\t_closer(out, street, order, got, target, float(fit[2]))\n", "\tif not skip.is_empty():\n\t\t_closer(out, street, order, got, target, float(fit[2]))\n", TF,
  "Nachrücken für jede Altstadt, nicht nur mit Brücke (AU-R4)"],
 ["M36", AF, "var fit := _street_fit(n, centre_m, block_m, share, _merged_stretches(skip), _merged_stretches(paved))",
  "var fit := _street_fit(n, centre_m, block_m, share, _merged_stretches(skip + late), _merged_stretches(paved))", TF,
  "Tunnel ändert die Blöcke der Stadt nur, wenn er den Anteil aus dem Band schiebt (AU-R4)"],
 ["M37", AF, "return AudioFeed.deck_of(str(b.get(\"type\", \"\"))) == \"stone\")", "return true)", TF,
  "nur Steinbrücken sind schon gepflastert (AU-R4)"],
 ["M38", AF, "func(_t: Dictionary) -> bool: return true)", "func(_t: Dictionary) -> bool: return false)", TF,
  "Tunnel der Etappe aus dem Plan (AU-R4)"],
 ["M39", AF, "bridge_stretches(plan, len_km, _time_scale), stone_stretches(plan, len_km, _time_scale),",
  "bridge_stretches(plan, len_km, _time_scale), [],", TF, "der Feed gibt die Steinbrücken weiter (AU-R4)"],
 ["M40", AF, "\t\t\t\ttunnel_stretches(plan, len_km, _time_scale))", "\t\t\t\t[])", TF,
  "der Feed gibt die Tunnel weiter (AU-R4)"],
]
json.dump(extra, open("/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R4/tools/mutations_extra.json", "w"), indent=1, ensure_ascii=False)
print("written", len(extra))
