import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()


def rep(old, new, count=1):
    global s
    if s.count(old) != count:
        raise SystemExit("pattern count %d != %d: %r" % (s.count(old), count, old[:70]))
    s = s.replace(old, new)


# --- DETAIL hook table -------------------------------------------------------------------------------------
rep('''#   graze    patches end where the body turns away from their projection: triangles on surface whose
#            normal is at less than this cosine to the projection axis are dropped. The sprites show such
#            stretched triangles edge-on (0 = keep them); seen from the side they are streaks on the flank
DETAIL = dict(ring=1.0, step=1.0, res=1.0, off=1.0, min_off=0.0, wheel=1.0, extras=False, graze=0.0)
''', '''#   graze    patches end where the body turns away from their projection: triangles on surface whose
#            normal is at less than this cosine to the projection axis are dropped. The sprites show such
#            stretched triangles edge-on (0 = keep them); seen from the side they are streaks on the flank
#   conform  patches are triangulated together with the body faces under them (no grid): every patch triangle
#            lies inside one body face, a constant height above it, and takes the body's smooth normals - so
#            the heights of the design hold on a coarse body (the grid patches of a coarse level had to float
#            2.5 times higher and stood out as blocks)
#   crease   depth (m) of the undercut under the shoulder line: the flank folds there instead of rolling over
#            (a light-catcher line; the widest point of the body stays where it is)
#   arch_r   radius (m) of the edge of the wheel-arch openings (None = the bottom radius of the design)
#   seam     scale of the width of panel gaps (a 4.5 mm gap is a third of a pixel from the chase camera)
DETAIL = dict(ring=1.0, step=1.0, res=1.0, off=1.0, min_off=0.0, wheel=1.0, extras=False, graze=0.0,
              conform=False, crease=0.0, arch_r=None, seam=1.0)
''')

rep('''    __slots__ = ("y", "w", "z_deck", "crown", "z_edge", "x_de", "z_sh", "z_start", "z_bot", "tuck_ref",
                 "tumble_up", "r_e", "r_b")''', '''    __slots__ = ("y", "w", "z_deck", "crown", "z_edge", "x_de", "z_sh", "z_start", "z_bot", "tuck_ref",
                 "tumble_up", "r_e", "r_b", "r_arc")''')

rep('''        self.glass_outlines = []        # (projection, symmetric, outline) of every pane (ce3d/vehicles3d.py)
''', '''        self.glass_outlines = []        # (projection, symmetric, outline) of every pane (ce3d/vehicles3d.py)
        self.glass_pillars = []         # (projection, symmetric, outline) of the dividers standing in a pane
        self._tri_cache = {}            # conform patches: triangles of the ray-cast targets
''')

# --- frame: arch edge radius ---------------------------------------------------------------------------------
rep('''        f.z_sh = z_sh
        f.z_start = z_start
        f.z_bot = z_bot
        return f
''', '''        f.z_sh = z_sh
        f.z_start = z_start
        f.z_bot = z_bot
        # 3D hook: a tighter edge where the section starts at a wheel-arch opening
        ar = self.detail["arch_r"]
        f.r_arc = f.r_b if (ar is None or za is None or za <= z_bot + 0.004) else min(f.r_b, ar)
        return f
''')

rep('''    def side_x(self, f, z):
        """Lower side half-width at height z (rocker tuck below the shoulder)."""
        span = max(0.05, f.z_sh - f.tuck_ref)
        t = min(1.4, max(0.0, (f.z_sh - z) / span))
        return f.w - self.tuck(f.y) * t ** 1.8 + self.flare(f.y, z)
''', '''    def side_x(self, f, z):
        """Lower side half-width at height z (rocker tuck below the shoulder)."""
        span = max(0.05, f.z_sh - f.tuck_ref)
        t = min(1.4, max(0.0, (f.z_sh - z) / span))
        x = f.w - self.tuck(f.y) * t ** 1.8 + self.flare(f.y, z)
        c = self.detail["crease"]
        if c > 0.0 and z < f.z_sh:
            # 3D hook: undercut below the shoulder line, fading out towards the rounded ends of the body
            u = (f.z_sh - z) / 0.05
            k = C.smoothstep(0.0, 0.45, f.y - self.lb0) * C.smoothstep(0.0, 0.6, self.lb1 - f.y)
            x -= c * k * u * math.exp(1.0 - u)
        return x
''')

rep('''        # bottom rounding
        pts += C.arc(xu, z0 + f.r_b, f.r_b, -90, 0, N["rb"], rx=x_low - xu)
        # lower side up to the shoulder
        zs = [z0 + f.r_b + (f.z_sh - z0 - f.r_b) * t for t in C.spacing(N["ls"], "cos")[1:]]''', '''        # bottom rounding (r_arc = r_b unless a 3D build asks for a tighter wheel-arch edge)
        if f.r_arc != f.r_b:
            x_low = self.side_x(f, z0 + f.r_arc)
            xu = max(0.02, x_low - f.r_arc)
            pts = [(xu * i / N["under"], z0) for i in range(N["under"])]
        pts += C.arc(xu, z0 + f.r_arc, f.r_arc, -90, 0, N["rb"], rx=x_low - xu)
        # lower side up to the shoulder
        zs = [z0 + f.r_arc + (f.z_sh - z0 - f.r_arc) * t for t in C.spacing(N["ls"], "cos")[1:]]''')

# --- patches: conform mode ------------------------------------------------------------------------------------
rep('''        bm = bmesh.new()
        for (ol, sgn) in variants:
            self._patch_into(bm, ol, proj, offset, res, walls, sgn, normal_offset, target)
        if len(bm.faces) == 0:
            bm.free()
            return None
        mats = [mat] if wall_mat is None else [mat, wall_mat]
        ob = MU.make(self.name + "_" + name, bm, mats, parent=self.center, smooth=smooth, sharp_deg=60)
        return ob
''', '''        bm = bmesh.new()
        normals = {} if dt["conform"] else None        # conform patches: body normal per patch vertex
        for (ol, sgn) in variants:
            if normals is not None:
                self._patch_conform(bm, ol, proj, offset, walls, sgn, target, normals)
            else:
                self._patch_into(bm, ol, proj, offset, res, walls, sgn, normal_offset, target)
        if len(bm.faces) == 0:
            bm.free()
            return None
        mats = [mat] if wall_mat is None else [mat, wall_mat]
        if normals is not None:
            # the patch shades like the body under it: corner normals of the top faces from the body
            bm.verts.index_update()
            bm.faces.index_update()
            loop_n = []
            for f in bm.faces:
                for lp in f.loops:
                    nv = normals.get(lp.vert.index) if f.material_index == 0 else None
                    loop_n.append(tuple(nv) if nv is not None else (0.0, 0.0, 0.0))
            ob = MU.make(self.name + "_" + name, bm, mats, parent=self.center, smooth=True, sharp_deg=60)
            ob.data.normals_split_custom_set(loop_n)
            return ob
        ob = MU.make(self.name + "_" + name, bm, mats, parent=self.center, smooth=smooth, sharp_deg=60)
        return ob

    # --- conform patches (3D hook, detail "conform") ---------------------------------------------------------

    def _target_tris(self, target):
        """Triangles of a ray-cast target in build space: (BVH of triangles, corner positions (T, 3) of
        Vectors, corner normals, face normals)."""
        if target in self._tri_cache:
            return self._tri_cache[target]
        deps = bpy.context.evaluated_depsgraph_get()
        deps.update()
        verts, tris, cnor, fnor = [], [], [], []
        for ob in self.targets[target]:
            ev = ob.evaluated_get(deps)
            me = ev.to_mesh()
            me.calc_loop_triangles()
            mw = ob.matrix_world.copy()
            m3 = mw.to_3x3()
            base = len(verts)
            verts += [mw @ v.co for v in me.vertices]
            cn = me.corner_normals
            for lt in me.loop_triangles:
                tris.append(tuple(base + i for i in lt.vertices))
                cnor.append(tuple((m3 @ Vector(cn[li].vector)).normalized() for li in lt.loops))
                fnor.append((m3 @ lt.normal).normalized())
            ev.to_mesh_clear()
        bvh = BVHTree.FromPolygons(verts, tris, all_triangles=True)
        import numpy as np
        pos = np.array([[tuple(verts[i]) for i in t] for t in tris], dtype=np.float64).reshape(-1, 3, 3)
        self._tri_cache[target] = (bvh, verts, tris, cnor, fnor, pos, np.array([tuple(n) for n in fnor]).reshape(-1, 3))
        return self._tri_cache[target]

    def _patch_conform(self, bm, outline, proj, offset, walls, sgn, target, normals):
        """Patch triangulated together with the body triangles under the outline: no grid, every triangle of
        the patch lies inside one triangle of the body. Vertices are ray-cast like those of the grid patches."""
        import numpy as np
        bvh, verts, tris, cnor, fnor, tpos, tfn = self._target_tris(target)
        if proj == "rear":
            org, dvec, ua, va = (lambda u, v: Vector((u, -3.0, v))), Vector((0.0, 1.0, 0.0)), 0, 2
        elif proj == "front":
            org, dvec, ua, va = (lambda u, v: Vector((u, self.L + 3.0, v))), Vector((0.0, -1.0, 0.0)), 0, 2
        elif proj == "side":
            org, dvec, ua, va = (lambda u, v: Vector((sgn * 4.0, u, v))), Vector((-sgn, 0.0, 0.0)), 1, 2
        else:
            org, dvec, ua, va = (lambda u, v: Vector((u, v, 6.0))), Vector((0.0, 0.0, -1.0)), 0, 1
        us = [p[0] for p in outline]
        vs = [p[1] for p in outline]
        u0, u1, v0, v1 = min(us), max(us), min(vs), max(vs)
        # depth range of the surface under the outline (boundary samples): faces far behind it stay out
        depths = []
        n = len(outline)
        for i in range(n):
            a, b = outline[i], outline[(i + 1) % n]
            for t in (0.0, 0.5):
                h = bvh.ray_cast(org(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), dvec, 50.0)
                if h[0] is not None:
                    depths.append(h[3])
        cu, cv = sum(us) / n, sum(vs) / n
        h = bvh.ray_cast(org(cu, cv), dvec, 50.0)
        if h[0] is not None:
            depths.append(h[3])
        if not depths:
            return
        d0, d1 = min(depths) - 0.06, max(depths) + 0.06
        index = {}
        pts = []

        def vid(u, v):
            key = (round(u * 2e5), round(v * 2e5))
            i = index.get(key)
            if i is None:
                i = len(pts)
                index[key] = i
                pts.append(Vector((u, v)))
            return i
        faces = [[vid(p[0], p[1]) for p in outline]]
        o0 = org(0.0, 0.0)
        graze = self.detail["graze"]
        dv = np.array(tuple(dvec))
        tu, tv = tpos[:, :, ua], tpos[:, :, va]
        dep = (tpos.mean(axis=1) - np.array(tuple(o0))) @ dv
        sel = ((tfn @ dv) < -max(graze * 0.5, 0.02)) & (tu.max(axis=1) >= u0) & (tu.min(axis=1) <= u1) & \
            (tv.max(axis=1) >= v0) & (tv.min(axis=1) <= v1) & (dep >= d0) & (dep <= d1)
        for ti in np.nonzero(sel)[0]:
            f = [vid(float(tu[ti, k]), float(tv[ti, k])) for k in range(3)]
            if len(set(f)) < 3:
                continue
            a2 = (pts[f[1]] - pts[f[0]]).cross(pts[f[2]] - pts[f[0]])
            if abs(a2) < 1e-11:
                continue
            faces.append(f if a2 > 0 else [f[0], f[2], f[1]])
        try:
            out = mgeo.delaunay_2d_cdt(pts, [], faces, 1, 1e-7, False)
        except Exception:
            return
        vco, ofaces = out[0], out[2]
        axis = dvec
        hits = {}

        def hit(i):
            if i not in hits:
                h = bvh.ray_cast(org(vco[i][0], vco[i][1]), dvec, 50.0)
                if h[0] is None:
                    hits[i] = None
                else:
                    loc, nor, ti, _d = h
                    if nor.dot(dvec) > 0:
                        nor = -nor
                    # smooth normal of the body at the hit: barycentric mix of the corner normals
                    a, b, c = (verts[k] for k in tris[ti])
                    w = mgeo.barycentric_transform(loc, a, b, c, Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
                    sn = cnor[ti][0] * max(w[0], 0.0) + cnor[ti][1] * max(w[1], 0.0) + cnor[ti][2] * max(w[2], 0.0)
                    if sn.length < 1e-6 or sn.dot(nor) < 0.2:
                        sn = nor
                    hits[i] = (loc, nor, sn.normalized())
            return hits[i]
        vmap = {}
        top = []
        for fi in ofaces:
            if len(fi) != 3:
                continue
            cx = (vco[fi[0]][0] + vco[fi[1]][0] + vco[fi[2]][0]) / 3.0
            cy = (vco[fi[0]][1] + vco[fi[1]][1] + vco[fi[2]][1]) / 3.0
            if not _inside(cx, cy, outline):
                continue
            hs = [hit(i) for i in fi]
            if any(x is None for x in hs):
                continue
            if graze > 0.0 and min(abs(x[1].dot(axis)) for x in hs) < graze:
                continue
            # a triangle that bridges two surfaces at different depths (edge of a bumper ledge) is no patch
            dd = [(x[0] - o0).dot(dvec) for x in hs]
            ext = max(max(abs(vco[fi[k]][0] - vco[fi[k - 1]][0]), abs(vco[fi[k]][1] - vco[fi[k - 1]][1])) for k in range(3))
            if max(dd) - min(dd) > 0.03 + 4.0 * ext:
                continue
            vl = []
            for i, x in zip(fi, hs):
                if i not in vmap:
                    v = bm.verts.new(x[0] + x[1] * offset)
                    vmap[i] = v
                vl.append(vmap[i])
            try:
                f = bm.faces.new(vl)
            except ValueError:
                continue
            f.material_index = 0
            top.append((f, hs[0][1]))
        bm.normal_update()
        for f, nrm in top:
            if f.normal.dot(nrm) < 0:
                f.normal_flip()
        bm.verts.index_update()
        for i, v in vmap.items():
            normals[v.index] = hits[i][2]
        if walls > 0.0:
            inv = {v: k for k, v in vmap.items()}
            topset = {f for f, _n in top}
            bedges = [e for e in bm.edges if e.is_boundary and e.verts[0] in inv and e.verts[1] in inv
                      and e.link_faces and e.link_faces[0] in topset]
            low = {}
            for e in bedges:
                for v in e.verts:
                    if v not in low:
                        loc, nor, _sn = hits[inv[v]]
                        low[v] = bm.verts.new(loc - nor * 0.002)
            for e in bedges:
                a, b = e.verts
                f0 = e.link_faces[0]
                loop = [l for l in f0.loops if l.edge == e][0]
                if loop.vert != a:
                    a, b = b, a
                try:
                    wf = bm.faces.new((b, a, low[a], low[b]))
                    wf.material_index = 1
                except ValueError:
                    pass
            bm.verts.index_update()
''')

open(p, 'w', encoding='utf-8').write(s)
print("carbody patched")
