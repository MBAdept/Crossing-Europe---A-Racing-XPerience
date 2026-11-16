from patchlib import patch

patch("tools/blender/ce3d/decalgeo.py", [
    ('''        uv = self.pos[:, :, [ua, va]]
        cand = (dot >= n_lo) & (uv[:, :, 0].max(axis=1) >= lo2[0]) & (uv[:, :, 0].min(axis=1) <= hi2[0]) & \\
            (uv[:, :, 1].max(axis=1) >= lo2[1]) & (uv[:, :, 1].min(axis=1) <= hi2[1])
        ids = np.nonzero(cand)[0]
''', '''        uv = self.pos[:, :, [ua, va]]
        cand = (dot >= n_lo) & (uv[:, :, 0].max(axis=1) >= lo2[0]) & (uv[:, :, 0].min(axis=1) <= hi2[0]) & \\
            (uv[:, :, 1].max(axis=1) >= lo2[1]) & (uv[:, :, 1].min(axis=1) <= hi2[1])
        if proj in ("rear", "front") and cand.any():
            # only the end of the body that faces the viewer: the walls of the wheel arches face the same
            # way further inside and would lie behind it in this projection
            depth = self.pos.mean(axis=1) @ axis
            cand &= depth >= depth[cand].max() - END_DEPTH_M
        ids = np.nonzero(cand)[0]
'''),
    ('''            if best_t < 0:
                continue
            t = best_t
            p3 = best_w @ self.pos[t]
            n3 = best_w @ self.nor[t]
            n3 = n3 / np.maximum(np.linalg.norm(n3, axis=1, keepdims=True), 1e-12)
            # keep the winding of the body triangle
            if np.cross(p3[1] - p3[0], p3[2] - p3[0]) @ fn[t] < 0:
                p3, n3 = p3[::-1], n3[::-1]
            k = top_item(t, c2[0], c2[1], float(p3[:, 1].mean()))
            new_p.append(p3)
            new_n.append(n3)
            new_m.append(items[k]["mat"] if k >= 0 else self.mat[t])
            replaced.add(t)
''', '''            if best_t < 0:
                continue
            for t, w in pieces:
                p3 = w @ self.pos[t]
                n3 = w @ self.nor[t]
                n3 = n3 / np.maximum(np.linalg.norm(n3, axis=1, keepdims=True), 1e-12)
                # keep the winding of the body triangle
                if np.cross(p3[1] - p3[0], p3[2] - p3[0]) @ fn[t] < 0:
                    p3, n3 = p3[::-1], n3[::-1]
                # only the surface nearest to the viewer takes the decal; what lies behind keeps its own
                k = top_item(t, c2[0], c2[1], float(p3[:, 1].mean())) if t == best_t else -1
                new_p.append(p3)
                new_n.append(n3)
                new_m.append(items[k]["mat"] if k >= 0 else self.mat[t])
                replaced.add(t)
'''),
    ('''            best_t, best_h, best_w = -1, -1e30, None
            for s in bodies:
''', '''            best_t, best_h = -1, -1e30
            pieces = []
            for s in bodies:
'''),
    ('''                h = float((w.mean(axis=0) @ self.pos[t]) @ axis)
                if h > best_h:
                    best_t, best_h, best_w = t, h, w
''', '''                h = float((w.mean(axis=0) @ self.pos[t]) @ axis)
                pieces.append((t, w))
                if h > best_h:
                    best_t, best_h = t, h
'''),
    ('''AXES = {"rear": np.array([0.0, -1.0, 0.0]), "front": np.array([0.0, 1.0, 0.0]), "top": np.array([0.0, 0.0, 1.0])}
''', '''AXES = {"rear": np.array([0.0, -1.0, 0.0]), "front": np.array([0.0, 1.0, 0.0]), "top": np.array([0.0, 0.0, 1.0])}
END_DEPTH_M = 0.9          # rear / front decals reach this far into the body from its end
'''),
])
