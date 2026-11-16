"""AS3 scratch: copy the final pictures into the delivery folder under German names (stack the small contact
sheets, make the clip film and a strip of consecutive frames).   python3 deliver.py"""
import glob
import os
import shutil
import subprocess

from PIL import Image

S = os.path.dirname(os.path.abspath(__file__))
SH = os.path.join(S, "shots")
DL = os.path.join(os.path.dirname(os.path.dirname(S)), "deliver", "AS3")
HOURS = {"12": "mittag", "19.5": "daemmerung", "23": "nacht"}


def cp(src, dst):
    src = os.path.join(SH, src)
    if os.path.exists(src):
        shutil.copyfile(src, os.path.join(DL, dst))
        print("  ", dst)
    else:
        print("   FEHLT", src)


def stack(srcs, dst):
    ims = [Image.open(os.path.join(SH, s)).convert("RGB") for s in srcs if os.path.exists(os.path.join(SH, s))]
    if not ims:
        print("   FEHLT", dst)
        return
    w = max(i.size[0] for i in ims)
    h = sum(i.size[1] for i in ims) + 6 * (len(ims) - 1)
    out = Image.new("RGB", (w, h), (24, 26, 30))
    y = 0
    for i in ims:
        out.paste(i, (0, y))
        y += i.size[1] + 6
    out.save(os.path.join(DL, dst))
    print("  ", dst, out.size)


def main():
    os.makedirs(DL, exist_ok=True)
    for h, hn in HOURS.items():
        cp("f_lods_baeume_%s.png" % h, "stufen_baeume_%s.png" % hn)
        cp("f_lods_varianten_%s.png" % h, "stufen_varianten_b_%s.png" % hn)
        cp("f_lods_niedrig_%s.png" % h, "stufen_buesche_heide_felsen_%s.png" % hn)
    cp("f_lods_d20.png", "stufen_in_20m_ueberzeichnung.png")
    cp("f_umrisse.png", "umrisse_gegen_sprite.png")
    cp("f_nebel.png", "fernbild_im_nebel_gegen_sprite.png")
    for tag, de in (("tag", "tag"), ("nacht", "nacht")):
        cp("f_kontakt_tree__%s.png" % tag, "kontaktbogen_baeume_%s.png" % de)
        stack(["f_kontakt_bush__%s.png" % tag, "f_kontakt_cover__%s.png" % tag, "f_kontakt_heather_%s.png" % tag,
               "f_kontakt_rock__%s.png" % tag, "f_kontakt_cliff_%s.png" % tag],
              "kontaktbogen_buesche_heide_felsen_klippe_%s.png" % de)
    ab = {"fin_alpen_high_12": "ab_alpen_hoch_mittag", "fin_heide_high_12": "ab_heide_hoch_mittag",
          "fin_mittelmeer_high_12": "ab_mittelmeer_hoch_mittag", "fin_pyrenaeen_high_12": "ab_pyrenaeen_hoch_mittag",
          "fin_alpen_medium_19.5": "ab_alpen_mittel_daemmerung",
          "ab_heide_high_19.5": "ab_heide_hoch_daemmerung", "ab_heide_medium_12": "ab_heide_mittel_mittag",
          "ab_mittelmeer_medium_19.5": "ab_mittelmeer_mittel_daemmerung",
          "ab_pyrenaeen_medium_19.5": "ab_pyrenaeen_mittel_daemmerung",
          "ab_pyrenaeen_klippe_high_12": "ab_pyrenaeen_klippe_fehlt_in_modern"}
    for src, dst in ab.items():
        cp(src + "_ab_00.jpg", dst + ".jpg")
    # clip: film + four consecutive frames from the middle
    frames = sorted(glob.glob(os.path.join(S, "clip2", "c_*.png")))
    if frames:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "60", "-i",
                        os.path.join(S, "clip2", "c_%03d.png"), "-pix_fmt", "yuv420p", "-vf",
                        "scale=trunc(iw/2)*2:trunc(ih/2)*2", os.path.join(DL, "clip_baumreihe_120kmh.mp4")], check=False)
        print("   clip_baumreihe_120kmh.mp4", len(frames), "Bilder")
        mid = len(frames) // 2
        ims = [Image.open(f).convert("RGB") for f in frames[mid:mid + 4]]
        w, h = ims[0].size
        out = Image.new("RGB", (w * 4 + 18, h), (24, 26, 30))
        for k, i in enumerate(ims):
            out.paste(i, (k * (w + 6), 0))
        out.save(os.path.join(DL, "clip_folgebilder.png"))
        print("   clip_folgebilder.png", out.size)
    for old in ("clip_folgebilder_fern_60-300m.png", "clip_folgebilder_mittel.png"):
        p = os.path.join(DL, old)
        if os.path.exists(p) and frames:
            os.remove(p)
            print("   entfernt (alt)", old)


main()
