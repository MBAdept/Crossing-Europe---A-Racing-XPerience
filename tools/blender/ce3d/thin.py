"""N2 (after wave 6): thin box beams of a landmark as the material class "thin" (docs/modelle.md section 25).

A beam thinner than a pixel - the Riesenrad's spokes are 0.14 m, 0.17 px at 600 m - is hit by a pixel centre in one
frame and missed in the next: it shimmers while the camera moves (measured 6.5 / 8.8 / 4.5 % of the tile pixels
changing from frame to frame at 250 / 600 / 1 000 m, the sprite 2.1 / 0.6 / 0.1 %). landmark.gdshader (CE_THIN)
widens such a beam about its own axis to at least the width of a pixel and draws it with the share of that width it
really has (alpha = true width / drawn width) - what the sprite's mip filter does with its spokes.

For that a "thin" surface carries per corner
  NORMAL   the radial direction from the beam's axis to the corner (at 45 degrees to the two faces of a square
           beam): the shader moves the corner along it; the beam is shaded like a rounded bar
  COLOR.a  the beam's width in centimetres (1 .. 255 = 0.01 .. 2.55 m; THIN_MAX_M caps it)
and as "vpbr": COLOR.rgb the albedo (sRGB), UV = (roughness, metallic), UV2 = (lamp channel + 0.5, weight).
Only square beams (meshutil.bm_beam without h): the shader takes the corner's distance from the axis as width / sqrt 2.
The two end faces of every beam are dropped - they sit inside the rim, the hub or the chord the beam ends at.

Pure numpy (no bpy): props3d.build_baked (option "thin") finds the beams in Blender and hands their corners here.
Self-test: python3 tools/blender/ce3d/thin.py
"""
import numpy as np

THIN_MAX_M = 0.6          # thickest beam drawn as "thin" (the Riesenrad's pylon chords: 0.55 m)
WIDTH_STEP_M = 0.01       # COLOR.a unit
SQUARE_TOL = 0.05         # the sides of the cross-section (and the two ends) may differ by this share
MIN_ASPECT = 1.5          # a beam is at least this many times as long as it is wide (else: a block, not a beam)


def _quad_normal(c, q):
    p = c[list(q)]
    n = np.cross(p[2] - p[0], p[3] - p[1])
    ln = np.linalg.norm(n)
    return n / ln if ln > 1e-12 else n


def beam(corners, quads):
    """One box beam. corners (8, 3); quads: six lists of four corner indices, wound outwards (counter-clockwise seen
    from outside). Returns dict(axis (3,) unit, width m, length m, sides [4 quads], normals (8, 3) radial unit) or
    None when the box is no square beam (a cube or block, a frustum, sides differing by more than SQUARE_TOL)."""
    c = np.asarray(corners, dtype=np.float64).reshape(8, 3)
    qs = [list(q) for q in quads]
    if len(qs) != 6 or any(len(q) != 4 for q in qs) or sorted(i for q in qs for i in q) != sorted(list(range(8)) * 3):
        return None
    edges = {}
    for q in qs:
        for k in range(4):
            a, b = q[k], q[(k + 1) % 4]
            edges[(min(a, b), max(a, b))] = float(np.linalg.norm(c[a] - c[b]))
    if len(edges) != 12:
        return None
    (i0, i1), length = max(edges.items(), key=lambda kv: kv[1])
    axis = c[i1] - c[i0]
    axis /= max(np.linalg.norm(axis), 1e-12)
    caps = [q for q in qs if abs(float(np.dot(_quad_normal(c, q), axis))) > 0.99]
    sides = [q for q in qs if abs(float(np.dot(_quad_normal(c, q), axis))) < 0.01]
    if len(caps) != 2 or len(sides) != 4:
        return None
    ws = [edges[(min(q[k], q[(k + 1) % 4]), max(q[k], q[(k + 1) % 4]))] for q in caps for k in range(4)]
    w = float(np.mean(ws))
    if w <= 0.0 or (max(ws) - min(ws)) > SQUARE_TOL * w or length < MIN_ASPECT * w:
        return None
    centre = c.mean(axis=0)
    rel = c - centre
    off = rel - np.outer(rel @ axis, axis)
    r = np.linalg.norm(off, axis=1)
    if np.any(np.abs(r - w / np.sqrt(2.0)) > SQUARE_TOL * w):
        return None
    return dict(axis=axis, width=w, length=length, sides=sides, normals=off / r[:, None])


def side_triangles(b, corners):
    """(pos (8, 3, 3), nor (8, 3, 3), width (8, 3)) of the four side quads of beam b (beam()), two triangles each,
    wound as the quads."""
    c = np.asarray(corners, dtype=np.float64).reshape(8, 3)
    tri = [(q[0], q[1], q[2]) for q in b["sides"]] + [(q[0], q[2], q[3]) for q in b["sides"]]
    idx = np.array(tri, dtype=np.int64)
    return c[idx], b["normals"][idx], np.full(idx.shape, b["width"])


def width_code(w):
    """COLOR.a byte of width w (m)."""
    code = int(round(float(w) / WIDTH_STEP_M))
    if not 1 <= code <= 255:
        raise ValueError("thin beam of %.3f m: outside 0.01 .. 2.55 m" % float(w))
    return code


def _box(a, b, w):
    """Test helper: corners and outward quads of a square beam from a to b (as meshutil.bm_beam)."""
    a, b = np.asarray(a, dtype=np.float64), np.asarray(b, dtype=np.float64)
    z = (b - a) / np.linalg.norm(b - a)
    up = np.array([0.0, 0.0, 1.0]) if abs(z[2]) < 0.95 else np.array([1.0, 0.0, 0.0])
    x = np.cross(up, z)
    x /= np.linalg.norm(x)
    y = np.cross(z, x)
    cs = []
    for e in (a, b):
        for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            cs.append(e + x * sx * w / 2 + y * sy * w / 2)
    quads = [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
    return np.array(cs), quads


def _selftest():
    c, q = _box((1.0, 2.0, 3.0), (4.0, -2.0, 15.0), 0.14)
    b = beam(c, q)
    assert b is not None and abs(b["width"] - 0.14) < 1e-9, b
    assert abs(abs(float(np.dot(b["axis"], [3.0, -4.0, 12.0]) / 13.0)) - 1.0) < 1e-9
    pos, nor, wid = side_triangles(b, c)
    assert pos.shape == (8, 3, 3) and np.allclose(wid, 0.14)
    for t in range(8):
        n = np.cross(pos[t, 1] - pos[t, 0], pos[t, 2] - pos[t, 0])
        assert float(np.dot(n, nor[t].mean(axis=0))) > 0.0, "winding against the radial normals"
        assert abs(float(np.dot(nor[t, 0], b["axis"]))) < 1e-9
    # every corner lies w / sqrt 2 from the axis along its normal: widening by k moves it to k w / sqrt 2
    centre = c.mean(axis=0)
    for i in range(8):
        rel = c[i] - centre
        off = rel - b["axis"] * float(np.dot(rel, b["axis"]))
        assert np.allclose(off, b["normals"][i] * 0.14 / np.sqrt(2.0))
    assert beam(*_box((0, 0, 0), (0.1, 0, 0), 0.14)) is None          # a block, not a beam
    c2, q2 = _box((0, 0, 0), (0, 5, 0), 0.2)
    c2[4:] = c2[4:] * [1.3, 1.0, 1.3]                                  # one end wider: a frustum
    assert beam(c2, q2) is None
    assert width_code(0.14) == 14 and width_code(0.55) == 55
    print("thin selftest OK")


if __name__ == "__main__":
    _selftest()
