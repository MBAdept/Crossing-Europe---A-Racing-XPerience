import sys
path = sys.argv[1]
src = open(path, encoding="utf-8").read()
anchor = "\t_start_wall_ms = Time.get_ticks_msec()\n"
assert src.count(anchor) == 1, src.count(anchor)
extra = (
    "\tif plan.stage_id == \"kiel_hamburg\":   # TEMPORARY one-pixel probe of the golden gate\n"
    "\t\tvar px := ColorRect.new()\n"
    "\t\tpx.color = Color(1, 0, 1)\n"
    "\t\tpx.size = Vector2(1, 1)\n"
    "\t\tpx.position = Vector2(640, 300)\n"
    "\t\tadd_child(px)\n"
)
open(path, "w", encoding="utf-8").write(src.replace(anchor, anchor + extra))
print("injected")
