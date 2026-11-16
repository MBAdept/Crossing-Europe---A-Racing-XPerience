"""deliver.py: spectrogram labels with a Unicode font (DejaVu), the piece names with umlauts."""
import os

p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "deliver.py")
s = open(p, encoding="utf-8").read()
s = s.replace("""from PIL import Image, ImageDraw  # noqa: E402
""", """from PIL import Image, ImageDraw, ImageFont  # noqa: E402

try:
    FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
except OSError:
    FONT = None
""")
s = s.replace("""    dr.text((6, 4), title, fill=(240, 240, 240))
    dr.text((6, 20), "Frequenz logarithmisch 30 Hz (unten) bis 16 kHz (oben); Linien: Abschnitte", fill=(170, 170, 170))""",
              """    dr.text((6, 4), title, fill=(240, 240, 240), font=FONT)
    dr.text((6, 20), "Frequenz logarithmisch 30 Hz (unten) bis 16 kHz (oben); Linien: Abschnitte", fill=(170, 170, 170), font=FONT)""")
s = s.replace("""        dr.text((xx + 3, 44), lab, fill=(255, 255, 255))""",
              """        dr.text((xx + 3, 44), lab, fill=(255, 255, 255), font=FONT)""")
s = s.replace("""title=f"{cls.TITLE.split(' - ')[1]} – {e['bpm']:g} bpm""",
              """title=f"{NAMES[pid]} – {e['bpm']:g} bpm""")
s = s.replace("""report = {}
pieces = [""", """report = {}
NAMES = {"nachtfahrt": "Nachtfahrt", "rueckenwind": "Rückenwind"}
pieces = [""")
open(p, "w", encoding="utf-8").write(s)
print("font uses", s.count("font=FONT"), "NAMES" in s)
