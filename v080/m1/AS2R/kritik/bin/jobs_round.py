"""AS2R: the subset of the KRITIK-2 jobs that the comparison sheets of the rework need (01 player game camera,
02 player night, 10 traffic game camera, 13 LOD swaps, 16 defect evidence) - written as p.json / t.json / x.json
into jobs/round/ so the sheet scripts of the review find their tiles under out/tiles/<batch>/.
usage: jobs_round.py   (after jobs_all.py and jobs_x.py)"""
import json
import os
import re
import sys

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R/kritik/bin")
import klib as K

PL = "(kombi|sportwagen|gran_turismo|limousine|kompakt)"
TR = "(suv|van|sports|sedan|hatch|wagon)"
KEEP = {
    "p": [PL + r"_g8_day", PL + r"_g9_ss", PL + r"_g9_ss_neutral", PL + r"_g9_mask_ss", PL + r"_g30_day", PL + r"_g8_low",
          PL + r"_g8_nighttail", PL + r"_g8_nightbrake", PL + r"_g8_daybrake",
          PL + r"_night_(reverse|rear_tail|rear_brake|tail|brake)",
          r"(sportwagen|gran_turismo)_lod0_(wheelf_low|wheelf|side)", r"(sportwagen|gran_turismo)_show_side",
          PL + r"_clay_rear34", r"(kombi|gran_turismo)_lod0_wheel", PL + r"_lod0_rear34", PL + r"_lod0_rearclose"],
    "t": [TR + r"_g\d+_lod\d_day", TR + r"_g\d+_lod\d_ss", r"empty_day", r"empty_day_ss3", r"empty_night",
          r"van_lod2_side", r"van_lod[012]_rear34", r"suv_lod[012]_(rear34|side)", r"suv_lod0_frontclose",
          r"(suv|van|sports)_paint_.*", TR + r"_lod0_night_(tail|reverse|off_day)", r"suv_lod[01]_night_tail"],
    "x": [TR + r"_g\d+_lod\d_nightlod", r"(sportwagen|gran_turismo|traffic_sports)_(secw|sidew)f.*",
          r"gran_turismo_sweep(nf)?_3"],
}


def main():
    out = os.path.join(K.JOBS, "round")
    os.makedirs(out, exist_ok=True)
    for b, pats in KEEP.items():
        jobs = json.load(open(os.path.join(K.JOBS, b + ".json")))
        rx = re.compile("^(" + "|".join(pats) + ")$")
        sel = [j for j in jobs if rx.match(j["name"])]
        json.dump(sel, open(os.path.join(out, b + ".json"), "w"), indent=0)
        print(b, len(sel), "von", len(jobs))


main()
