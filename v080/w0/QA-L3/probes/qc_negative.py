#!/usr/bin/env python3
"""QA lens 3: counter-tests of tools/audio/qc/audio_qc.py – each case damages a copy of assets/audio/modern in one
way and expects the tool to fail (exit code != 0) and to name the sound."""
import json, os, shutil, struct, subprocess, sys, wave, hashlib
import numpy as np
tree, work = sys.argv[1], sys.argv[2]
src = os.path.join(tree, 'assets/audio/modern')
tool = os.path.join(tree, 'tools/audio/qc/audio_qc.py')

def fresh(name):
    d = os.path.join(work, name)
    shutil.rmtree(d, ignore_errors=True)
    shutil.copytree(src, d)
    return d

def read_wav(p):
    with wave.open(p, 'rb') as w:
        n, ch, sr, sw = w.getnframes(), w.getnchannels(), w.getframerate(), w.getsampwidth()
        x = np.frombuffer(w.readframes(n), dtype='<i2').reshape(-1, ch).copy()
    return x, sr

def write_wav(p, x, sr, sw=2):
    with wave.open(p, 'wb') as w:
        w.setnchannels(x.shape[1]); w.setsampwidth(sw); w.setframerate(sr)
        w.writeframes(x.astype('<i2').tobytes() if sw == 2 else x.astype('u1').tobytes())

def fix_manifest(d, folder, sid, path, **extra):
    mp = os.path.join(d, folder, 'manifest.json')
    m = json.load(open(mp))
    e = m['sounds'][sid]
    data = open(path, 'rb').read()
    e['sha256'] = hashlib.sha256(data).hexdigest(); e['bytes'] = len(data)
    e.update(extra)
    json.dump(m, open(mp, 'w'), indent=1)

def run(d, *args):
    r = subprocess.run([sys.executable, tool, '--root', d, '--no-import', *args], capture_output=True, text=True)
    bad = [l for l in r.stdout.splitlines() if 'FEHLER' in l]
    return r.returncode, bad, r.stdout

cases = []
# 0. control: the untouched copy passes (with --no-import as in every case)
d = fresh('control'); cases.append(('control (untouched copy)', run(d), False))
# 1. one byte changed, manifest untouched -> sha256
d = fresh('sha'); p = os.path.join(d, 'sfx/platzhalter_hit.wav'); b = bytearray(open(p, 'rb').read()); b[200] ^= 1; open(p, 'wb').write(b)
cases.append(('byte flipped, manifest unchanged', run(d), True))
# 2. clipping: a run of full-scale samples (manifest hash updated, so only the signal check can find it)
d = fresh('clip'); p = os.path.join(d, 'sfx/platzhalter_hit.wav'); x, sr = read_wav(p); x[1000:1040, :] = 32767; write_wav(p, x, sr); fix_manifest(d, 'sfx', 'platzhalter_hit', p)
cases.append(('40 samples at full scale', run(d), True))
# 3. DC offset of -26 dBFS
d = fresh('dc'); p = os.path.join(d, 'vehicle/platzhalter_loop.wav'); x, sr = read_wav(p); x = np.clip(x.astype(np.int32) + 1640, -32768, 32767); write_wav(p, x, sr); fix_manifest(d, 'vehicle', 'platzhalter_loop', p)
cases.append(('DC offset 0.05 (-26 dBFS)', run(d), True))
# 4. loop seam: a step at the end of the loop
d = fresh('seam'); p = os.path.join(d, 'vehicle/platzhalter_loop.wav'); x, sr = read_wav(p); x[-1, :] = 20000; x[0, :] = -20000; write_wav(p, x, sr); fix_manifest(d, 'vehicle', 'platzhalter_loop', p)
cases.append(('step of 40000 LSB across the loop point', run(d), True))
# 5. true peak above -1 dBTP: scale the one-shot up to -0.2 dBFS sample peak
d = fresh('peak'); p = os.path.join(d, 'ui/platzhalter_blip.wav'); x, sr = read_wav(p); g = 0.977 * 32767 / max(1, np.abs(x).max()); x = np.round(x * g); write_wav(p, x, sr); fix_manifest(d, 'ui', 'platzhalter_blip', p)
cases.append(('sample peak raised to -0.2 dBFS', run(d), True))
# 6. wrong sample rate (48 kHz header)
d = fresh('rate'); p = os.path.join(d, 'ui/platzhalter_blip.wav'); x, sr = read_wav(p); write_wav(p, x, 48000); fix_manifest(d, 'ui', 'platzhalter_blip', p, sample_rate=48000)
cases.append(('48 kHz WAV (manifest says 48 kHz too)', run(d), True))
# 7. unknown file in a folder
d = fresh('extra'); shutil.copy(os.path.join(d, 'ui/platzhalter_blip.wav'), os.path.join(d, 'ui/unbekannt.wav'))
cases.append(('file the manifest does not know', run(d), True))
# 8. file missing
d = fresh('missing'); os.remove(os.path.join(d, 'music/platzhalter_takt.ogg'))
cases.append(('file of a manifest entry missing', run(d), True))
# 9. budget: sounds over 0.1 MB
d = fresh('budget'); cases.append(('budget of 0.1 MB for sounds', run(d, '--budget-sounds-mb', '0.1'), True))
# 10. wrong loudness in the manifest (off by 2 dB)
d = fresh('lufs'); mp = os.path.join(d, 'music/manifest.json'); m = json.load(open(mp)); m['sounds']['platzhalter_takt']['lufs'] += 2.0; json.dump(m, open(mp, 'w'))
cases.append(('manifest loudness off by 2 dB', run(d), True))
# 11. loop points outside the file
d = fresh('looppts'); mp = os.path.join(d, 'vehicle/manifest.json'); m = json.load(open(mp)); m['sounds']['platzhalter_loop']['loop'] = [0, 99999]; json.dump(m, open(mp, 'w'))
cases.append(('loop end beyond the file', run(d), True))
# 12. music far from -14 LUFS: scale via ffmpeg (-8 dB), manifest re-measured values not updated except hash
d = fresh('musiclvl'); p = os.path.join(d, 'music/platzhalter_takt.ogg'); q = p + '.tmp.ogg'
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', p, '-af', 'volume=-8dB', '-c:a', 'libvorbis', '-q:a', '5', q], check=True); os.replace(q, p)
m = json.load(open(os.path.join(d, 'music/manifest.json'))); e = m['sounds']['platzhalter_takt']; e['lufs'] -= 8.0; e['true_peak_db'] -= 8.0; json.dump(m, open(os.path.join(d, 'music/manifest.json'), 'w')); fix_manifest(d, 'music', 'platzhalter_takt', p)
cases.append(('music 8 dB too quiet (manifest says so)', run(d), True))
# 13. a click in the middle of a loop (not at the seam) - the report says this is NOT found
d = fresh('midclick'); p = os.path.join(d, 'vehicle/platzhalter_loop.wav'); x, sr = read_wav(p); x[20000, :] = 30000; x[20001, :] = -30000; write_wav(p, x, sr); fix_manifest(d, 'vehicle', 'platzhalter_loop', p)
r = run(d); cases.append(('click in the middle of a loop (documented limit)', r, None))
fails = 0
for name, (code, bad, out), _exp in cases:
    expect = None if name.startswith('click in the middle') else (not name.startswith('control'))
    ok = (code != 0) == expect if expect is not None else True
    fails += 0 if ok else 1
    print('%-48s exit %d  %s  %s' % (name, code, 'as expected' if ok else 'NOT DETECTED' if expect else 'UNEXPECTED FAILURE', (bad[0][:150] if bad else '')))
    if not ok or (expect and not bad):
        tail = [l for l in out.splitlines() if l.strip()][-4:]
        for l in tail: print('      |', l[:200])
sys.exit(1 if fails else 0)
