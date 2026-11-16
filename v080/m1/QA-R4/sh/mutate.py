#!/usr/bin/env python3
"""QA-R4 mutation runner: break one line per rule in the scratch copy, run the guarding test, restore.
mutate.py <id>[,<id>...]  (ids from MUTATIONS); results appended to logs/mutations.tsv"""
import os, subprocess, sys, time, shutil

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R4"
MUT = S + "/mut"
WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-3"

UNIT = ["godot", "--headless", "--path", ".", "-s", "res://tests/run_tests.gd", "--"]
def unit(f):
    return UNIT + ["--filter=" + f]
def render(f, only):
    return ["xvfb-run", "-a", "-s", "-screen 0 1280x720x24", "godot", "--path", ".", "--rendering-driver", "opengl3",
            "--audio-driver", "Dummy", "--fixed-fps", "60", "-s", "res://tests/race3d/render/" + f, "--",
            "--graphics=modern", "--gfx-sync", "--audio-sync", "--only=" + only]
def headless(f, only):
    return ["godot", "--headless", "--path", ".", "-s", "res://tests/race3d/" + f, "--", "--only=" + only]

# id: (file, old, new, command, rule)
MUTATIONS = {
    "U1": ("scripts/race3d/layers/weather.gd",
           "const RAIN_BOX: Array[Vector3] = [Vector3(14.0, 3.0, 45.0),",
           "const RAIN_BOX: Array[Vector3] = [Vector3(24.0, 3.0, 70.0),",
           unit("test_weather"), "Teilchen: jede Stufe mindestens Arcades Dichte"),
    "U2": ("scripts/race3d/layers/lights.gd",
           "const LIGHT_MASK := 0xFFFFF & ~2 & ~(1 << 19)",
           "const LIGHT_MASK := 0xFFFFF & ~2",
           unit("test_light_pool"), "Aufwärm-Ebene: echte Lichter lassen Ebene 20 aus"),
    "U3": ("scripts/race3d/environment_rig.gd",
           "\tif _zones.has(\"tunnel\"):\n\t\ttunnel01 = float(_zones[\"tunnel\"])",
           "\tif false:\n\t\ttunnel01 = float(_zones[\"tunnel\"])",
           unit("test_environment_rig"), "set_zone(\"tunnel\") ersetzt tunnel_blend"),
    "U4": ("scripts/race3d/environment_rig.gd",
           "const MOON_MIN_ELEV_DEG := 55.0",
           "const MOON_MIN_ELEV_DEG := 15.0",
           unit("test_environment_rig"), "Nachtgesetz: Mond ≥ 55°"),
    "U5": ("scripts/race3d/environment_rig.gd",
           "\treturn EXIT_AFTER * (1.0 - smoothstep(0.0, EXIT_AFTER_M, d))",
           "\treturn EXIT_AFTER * (1.0 - smoothstep(0.0, EXIT_AFTER_M * 10.0, d))",
           unit("test_environment_rig"), "Nachglühen klingt über EXIT_AFTER_M ab (Mutation: 10× länger)"),
    "U6": ("scripts/race3d/layers/lights.gd",
           "\tif lights <= 0.04:\n\t\treturn {}\n\tvar best: Dictionary = {}",
           "\tif lights < -1.0:\n\t\treturn {}\n\tvar best: Dictionary = {}",
           unit("test_light_pool"), "Blaulicht-Licht nur nachts"),
    "U7": ("scripts/race3d/layers/weather.gd",
           "\tif not full:\n\t\treturn [[rear + back * 0.5 + up * 0.45, Vector2(w * 0.75, 0.6), 1.0, 0.6]]",
           "\tif not full:\n\t\treturn []",
           unit("test_weather"), "Gischt auch bei Effekte Aus (eine Wolke)"),
    "U8": ("scripts/race3d/builders/terrain.gd",
           "const BANK_MAX_M := 0.45",
           "const BANK_MAX_M := 0.95",
           unit("race3d/test_"), "Schneewall höchstens 0,45 m (Einheitstests race3d)"),
    "U9": ("scripts/race3d/layers/lights.gd",
           "if _beacon_on and i == omnis.size() - 1:",
           "if false and i == omnis.size() - 1:",
           unit("test_light_pool"), "Blaulicht nimmt ein Punktlicht des Pools (nur Render-Prüfung erwartet)"),
    "R1": ("assets/shaders/modern/road.gdshader",
           "uniform float night_lift = 0.08;",
           "uniform float night_lift = 0.0;",
           render("check_night.gd", "fahrbahn"), "N1 Fahrbahn nie dunkler als Arcade"),
    "R2": ("scripts/race3d/layers/weather.gd",
           "\t_fade = clampf(1.0 - tunnel01, 0.0, 1.0)",
           "\t_fade = 1.0",
           render("check_weather.gd", "tunnel"), "Niederschlag im Tunnel aus"),
    "R3": ("scripts/race3d/builders/terrain.gd",
           "Vector2(0.75, 1.0), Vector2(1.6, -0.12)]",
           "Vector2(0.75, 2.6), Vector2(1.6, -0.12)]",
           render("check_weather.gd", "schneewall"), "Schneewall-Geometrie höchstens 0,45 m (Profil-Scheitel ×2,6 = 0,78 m)"),
    "R4": ("scripts/race3d/builders/terrain.gd",
           "const BANK_H_M := 0.3\nconst BANK_MAX_M := 0.45",
           "const BANK_H_M := 0.8\nconst BANK_MAX_M := 0.95",
           render("check_weather.gd", "schneewall"), "Schneewall-Höhe (BANK_H_M 0,8 / BANK_MAX_M 0,95)"),
}


def main():
    ids = sys.argv[1].split(",")
    env = dict(os.environ)
    env["XDG_DATA_HOME"] = S + "/xdg_mut"
    env["MESA_SHADER_CACHE_DIR"] = S + "/mesa_mut"
    os.makedirs(env["XDG_DATA_HOME"], exist_ok=True)
    os.makedirs(env["MESA_SHADER_CACHE_DIR"], exist_ok=True)
    for mid in ids:
        f, old, new, cmd, rule = MUTATIONS[mid]
        path = os.path.join(MUT, f)
        orig = open(os.path.join(WT, f), encoding="utf-8").read()
        if orig.count(old) != 1:
            print(f"{mid}: pattern found {orig.count(old)} times in {f} – skipped", flush=True)
            with open(S + "/logs/mutations.tsv", "a") as o:
                o.write(f"{mid}\t{rule}\tMUSTER-FEHLT\t\n")
            continue
        open(path, "w", encoding="utf-8").write(orig.replace(old, new))
        t0 = time.time()
        log = S + f"/logs/mut_{mid}.log"
        try:
            with open(log, "w") as lf:
                rc = subprocess.run(["nice", "-n", "10", "timeout", "1500"] + cmd, cwd=MUT, env=env, stdout=lf, stderr=subprocess.STDOUT).returncode
        finally:
            shutil.copyfile(os.path.join(WT, f), path)
        txt = open(log, encoding="utf-8", errors="replace").read()
        fails = [l for l in txt.splitlines() if "FEHLER" in l or "FAIL" in l or "✗" in l]
        caught = rc != 0 or bool(fails)
        verdict = "ERKANNT" if caught else "NICHT ERKANNT"
        print(f"{mid}: {verdict} rc={rc} ({time.time() - t0:.0f} s) – {rule}", flush=True)
        for l in fails[:4]:
            print("    " + l[:220], flush=True)
        with open(S + "/logs/mutations.tsv", "a") as o:
            o.write(f"{mid}\t{rule}\t{verdict}\trc={rc}\t{(fails[0][:200] if fails else '')}\n")


if __name__ == "__main__":
    main()
