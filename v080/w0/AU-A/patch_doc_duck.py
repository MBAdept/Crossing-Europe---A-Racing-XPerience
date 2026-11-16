R = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/"
p = R + "config/game_config.json"
s = open(p, encoding="utf-8").read()
old = "um 0 bis depth_db, schnell hinunter (attack_s), langsam zurück (release_s). "
new = ("um 0 bis depth_db, schnell hinunter (attack_s), langsam zurück (release_s); was ein Mischzustand dem Auto nimmt "
       "(result), zählt mit – ein leise gestelltes Auto senkt die Musik nicht ab. ")
assert s.count(old) == 1, s.count(old)
open(p, "w", encoding="utf-8").write(s.replace(old, new))
import json
json.load(open(p, encoding="utf-8"))
print("ok")
