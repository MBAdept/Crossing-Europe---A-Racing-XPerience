"""clipframes.py <clip.mp4> <out.jpg> <scale> <t,t,...> [label]: frames of an A/B clip (Arcade | Modern) at the given
times stacked into one picture, each labelled with its time."""
import subprocess, sys, io
from PIL import Image, ImageDraw, ImageFont

clip, out, scale = sys.argv[1], sys.argv[2], float(sys.argv[3])
times = [float(t) for t in sys.argv[4].split(',')]
label = sys.argv[5] if len(sys.argv) > 5 else ''
try:
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 20)
except Exception:
    font = ImageFont.load_default()
rows = []
for t in times:
    png = subprocess.run(['ffmpeg', '-loglevel', 'error', '-ss', '%.3f' % t, '-i', clip, '-frames:v', '1', '-f', 'image2pipe',
                          '-vcodec', 'png', '-'], capture_output=True, check=True).stdout
    im = Image.open(io.BytesIO(png)).convert('RGB')
    im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
    c = Image.new('RGB', (im.width, im.height + 28), '#10182c')
    c.paste(im, (0, 28))
    ImageDraw.Draw(c).text((8, 3), '%s t = %.3f s  (links Arcade, rechts Modern)' % (label, t), fill='white', font=font)
    rows.append(c)
sheet = Image.new('RGB', (max(r.width for r in rows), sum(r.height for r in rows) + 4 * (len(rows) - 1)), '#000000')
y = 0
for r in rows:
    sheet.paste(r, (0, y))
    y += r.height + 4
sheet.save(out, quality=88)
print(out, sheet.size)
