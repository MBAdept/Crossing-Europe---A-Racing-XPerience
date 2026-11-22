#!/usr/bin/env python3
"""QA-R7b: break one line per rule in a scratch copy of the package head and see whether its test fails.
Usage: mutate.py <copy root> <out log> [ids…]"""
import os, subprocess, sys, time

ROOT = sys.argv[1]
OUT = sys.argv[2]
ONLY = sys.argv[3:]
S = os.path.dirname(OUT)
XDG = os.path.join(S, 'xdg_mut')
os.makedirs(XDG, exist_ok=True)
LM = 'scripts/race3d/builders/landmarks.gd'
SH = 'assets/shaders/modern/landmark.gdshader'
BD = 'scripts/race3d/layers/backdrop.gd'
PR = 'scripts/race3d/builders/props.gd'
RC = 'tests/race3d/render/check_landmarks_render.gd'

UNIT = ['godot', '--headless', '--path', '.', '-s', 'res://tests/run_tests.gd', '--', '--filter=test_landmarks']
def CHECK(only):
    return ['godot', '--headless', '--path', '.', '-s', 'res://tests/race3d/check_landmarks.gd', '--', '--only=' + only]
RENDER = ['xvfb-run', '-a', '-s', '-screen 0 1280x720x24', 'godot', '--path', '.', '--rendering-driver', 'opengl3',
          '--audio-driver', 'Dummy', '--resolution', '1280x720', '--fixed-fps', '60', '-s',
          'res://tests/race3d/render/check_landmarks_render.gd', '--', '--graphics=modern', '--gfx-sync', '--audio-sync']

# id, rule, [(file, old, new)], command
M = [
    ('M1', 'Arcade-Gesetz (Deckung 0,72 L)', [(LM, 'var keep := 1.0 - smoothstep(l * 0.72, l, d)', 'var keep := 1.0 - smoothstep(l * 0.70, l, d)')], UNIT),
    ('M2', 'Reichweite nachts bis landmark_far_m', [(LM, 'return maxf(landmark_range(vis, law), law.y if night > 0.05 else 0.0)', 'return landmark_range(vis, law)')], UNIT),
    ('M3', 'jede Stadt-Landmarke dargestellt (Leuchtturm)', [(LM, '["domed_church", "tv_tower", "lighthouse", "skyscrapers"]', '["domed_church", "tv_tower", "skyscrapers"]')], UNIT),
    ('M4', 'Anker der Form wie Arcade (Mitte)', [(LM, 'float(it.get("width_m", 30.0)) * 0.5 * sc', 'float(it.get("width_m", 30.0)) * 0.0 * sc')], UNIT),
    ('M5', 'Fernsehturm schlank (N2)', [(LM, 'kit.cylinder(c, 0.0, 40.0, 16.0, 11.5, 20, false)', 'kit.cylinder(c, 0.0, 40.0, 60.0, 11.5, 20, false)')], UNIT),
    ('M6', 'keine Instanz-Uniform (A-19)', [(SH, 'uniform vec4 lm_fade = vec4(1.0, 0.0, 0.0, 0.0);', 'uniform vec4 lm_fade = vec4(1.0, 0.0, 0.0, 0.0);\ninstance uniform float qa_probe = 0.0;')], UNIT),
    ('M7', 'Tönung im Bild-Material (N1)', [(LM, 'm.set_shader_parameter("shadow_cut", PropLibrary.STANDIN_SHADOW_CUT)\n\t\tm.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))', 'm.set_shader_parameter("shadow_cut", PropLibrary.STANDIN_SHADOW_CUT)')], UNIT),
    ('M7b', 'Tönung im Modell-Material (N1, A-19)', [(LM, '\t\tm.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))\n\t\tout.append(m)\n\treturn out\n\n\n## Hook of the renderer', '\t\tout.append(m)\n\treturn out\n\n\n## Hook of the renderer')], UNIT),
    ('M8', 'Reichweite auf dem Pfad (reichweite)', [(LM, 'var r := minf(reach(vis, night, _law), maxf(_path_m, vis))', 'var r := 900.0')], CHECK('reichweite,nacht')),
    ('M9', 'weich: durchscheinend ab 0,70 L', [(LM, '_apply(e as Dictionary, d, f, d >= _blend_from * l)', '_apply(e as Dictionary, d, f, false)')], CHECK('weich')),
    ('M10', 'Skyline blendet aus, solange das Wahrzeichen in Reichweite ist', [(BD, 'a = smoothstep(l, l * 1.15, dz) if dz > 0.0 else 0.0', 'a = 1.0')], CHECK('skyline')),
    ('M11', 'Stelle bei 600 m (position)', [(LM, '\t\tp["x"] = PropsBuilderMath.edge_anchor_x(', '\t\tp["x"] = 60.0 * float(side) + PropsBuilderMath.edge_anchor_x(')], CHECK('position')),
    ('M12', 'props.gd zeichnet kein Wahrzeichen (Weiche)', [(PR, '_skip_landmarks = renderer.call(&"builder", "landmarks") != null', '_skip_landmarks = false')], CHECK('reichweite')),
    ('M13', 'prozedurale Kuppelkirche Belgrad', [(LM, '["domed_church", "tv_tower", "lighthouse", "skyscrapers"]', '["tv_tower", "lighthouse", "skyscrapers"]')], CHECK('prozedural')),
    ('M14', 'Flugfeuer klein (Render)', [(SH, 'float r = min(max(UV2.x, UV2.y / max(px_per_m, 1.0e-4)), depth * 0.03);', 'float r = depth * 0.2;'),
                                       (RC, '\tawait _check_stelle()\n\tawait _check_weich()\n\tawait _check_nacht()\n', '')], RENDER),
    ('M15', 'Stelle im Bild (Render, Versatz 120 m)', [(LM, '\t\tp["x"] = PropsBuilderMath.edge_anchor_x(', '\t\tp["x"] = 120.0 * float(side) + PropsBuilderMath.edge_anchor_x('),
                                       (RC, '\tawait _check_weich()\n\tawait _check_nacht()\n\tawait _check_flugfeuer()\n', '')], RENDER),
    ('M16', 'Anstrahlung einer Requisite als Wahrzeichen (Modell, nachts)', [(SH, '\talb = mix(alb, alb * flood_color * 1.6, flood);\n', '')],
     ['bash', '-c', 'godot --headless --path . -s res://tests/run_tests.gd -- --filter=test_landmarks; godot --headless --path . -s res://tests/race3d/check_landmarks.gd -- --only=nacht']),
    ('M17', 'Anstrahlung einer Requisite als Wahrzeichen (Bild, nachts)', [(SH, '\td = mix(d, base * flood_color, flood);\n', '')],
     ['bash', '-c', 'godot --headless --path . -s res://tests/run_tests.gd -- --filter=test_landmarks; godot --headless --path . -s res://tests/race3d/check_landmarks.gd -- --only=nacht']),
]

log = open(OUT, 'a')
def w(s):
    print(s)
    log.write(s + '\n')
    log.flush()

for mid, rule, edits, cmd in M:
    if ONLY and mid not in ONLY:
        continue
    saved = {}
    ok = True
    for f, old, new in edits:
        p = os.path.join(ROOT, f)
        src = saved.get(p) or open(p).read()
        saved.setdefault(p, src)
        cur = open(p).read()
        if cur.count(old) != 1:
            w('%s %s: Ersetzung nicht eindeutig in %s (%d)' % (mid, rule, f, cur.count(old)))
            ok = False
            break
        open(p, 'w').write(cur.replace(old, new))
    if ok:
        env = dict(os.environ, XDG_DATA_HOME=XDG, MESA_SHADER_CACHE_DIR=os.path.join(XDG, 'mesa'))
        t0 = time.time()
        try:
            r = subprocess.run(['nice', '-n', '10'] + cmd, cwd=ROOT, env=env, capture_output=True, text=True, timeout=2400)
            outp = r.stdout + r.stderr
            rc = r.returncode
        except subprocess.TimeoutExpired as e:
            outp = (e.stdout or b'').decode() if isinstance(e.stdout, bytes) else (e.stdout or '')
            rc = -9
        open(os.path.join(S, 'mut_%s.log' % mid), 'w').write(outp)
        lines = [l for l in outp.splitlines() if ('FEHLER' in l or 'FAIL' in l or 'fehlgeschlagen' in l or 'Fehlschl' in l or 'CHECK' in l or 'bestanden' in l or 'passed' in l.lower())]
        caught = rc != 0 or any(('FEHLER' in l or 'FAIL' in l) for l in lines)
        w('%s %-58s rc=%d %s (%.0f s)' % (mid, rule, rc, 'ERKANNT' if caught else 'NICHT ERKANNT', time.time() - t0))
        for l in lines[:8]:
            w('    ' + l.strip()[:220])
    for p, src in saved.items():
        open(p, 'w').write(src)
w('MUT_DONE')
