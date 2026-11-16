#!/usr/bin/env python3
"""Scratch (wave-0 integration, not part of the repository): compares the ERGEBNIS lines of kernel_runs.sh.

Usage: compare_kernel.py <out dir> <case>...
Per case the logs <case>_arcade.log, <case>_stub.log and <case>_kernel.log are read: every key must equal the Arcade
run except "gfx"; the kernel run must really have used the kernel (PERF probe.kernel) and prints its numbers.
"""
import json
import sys


def line(path, prefix):
    try:
        for text in open(path, encoding="utf-8", errors="replace"):
            if text.startswith(prefix):
                return json.loads(text[len(prefix):])
    except OSError:
        pass
    return None


def main():
    ok = True
    out = sys.argv[1]
    for case in sys.argv[2:]:
        ref = line("%s/%s_arcade.log" % (out, case), "ERGEBNIS ")
        if ref is None:
            print("%s: ERGEBNIS des Arcade-Laufs fehlt" % case)
            ok = False
            continue
        print("%s: Arcade %d Schlüssel, time_s %s, distance_km %s, collisions %s" % (
            case, len(ref), ref.get("time_s"), ref.get("distance_km"), ref.get("collisions")))
        for kind in ("stub", "kernel"):
            res = line("%s/%s_%s.log" % (out, case, kind), "ERGEBNIS ")
            perf = line("%s/%s_%s.log" % (out, case, kind), "PERF ") or {}
            if res is None:
                print("  %-6s: ERGEBNIS fehlt" % kind)
                ok = False
                continue
            diff = sorted(k for k in set(ref) | set(res) if ref.get(k) != res.get(k))
            probe = perf.get("probe", {})
            good = diff == ["gfx"] and res.get("gfx") == "modern" and "gfx_fallback" not in res
            if kind == "kernel":
                good = good and bool(probe.get("kernel"))
            text = "  %-6s: verschieden %s, gfx %s, time_s %s -> %s" % (
                kind, diff, res.get("gfx"), res.get("time_s"), "OK" if good else "FEHLER")
            if kind == "kernel" and probe:
                st = probe.get("streamer", {})
                text += ("\n          Kern: %d Bilder, erstes update %.1f ms, danach Ø %.2f / max %.2f ms, Stücke max %d, "
                         "wartend max %d, Builds %d (Ø %.2f / max %.2f ms), Commits %d (max %.2f ms), Collect max %.2f ms, "
                         "Rebase %d, Neustarts %d, Kamera max %.0f m vom Ursprung, Blick max %.1f°, Track-Fenster max %d Segmente" % (
                             probe.get("updates", 0) + 1, probe.get("first_update_ms", 0.0), probe.get("update_ms_avg", 0.0),
                             probe.get("update_ms_max", 0.0), probe.get("chunks_max", 0), probe.get("pending_max", 0),
                             st.get("builds", 0), st.get("build_ms_avg", 0.0), st.get("build_ms_max", 0.0),
                             st.get("commits", 0), st.get("commit_ms_max", 0.0), st.get("collect_ms_max", 0.0),
                             st.get("rebases", 0), st.get("restarts", 0), probe.get("camera_from_origin_max_m", 0.0),
                             probe.get("look_yaw_max_deg", 0.0), probe.get("track_window_max", 0)))
            print(text)
            ok = ok and good
    print("KERN-HINTER-DER-NAHT", "OK" if ok else "FEHLER")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
