import math
import numpy as np
CUT_FILL_ALPHAS = tuple(round(0.05 * k, 2) for k in range(10))   # gap alphas _gap_alpha_auto chooses from (< 0.5)
CUT_FILL_MIPS = (0.5, 1.0, 1.0, 1.0)                              # weights of mips 1 - 4 in its error


def _components(mask):
    """Connected regions (4-neighbours) of a boolean image: list of (row index array, column index array)."""
    h, w = mask.shape
    lab = np.zeros((h, w), dtype=np.int32)
    out = []
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys.tolist(), xs.tolist()):
        if lab[y0, x0]:
            continue
        n = len(out) + 1
        lab[y0, x0] = n
        stack = [(y0, x0)]
        ry, rx = [], []
        while stack:
            y, x = stack.pop()
            ry.append(y)
            rx.append(x)
            for yy, xx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= yy < h and 0 <= xx < w and mask[yy, xx] and not lab[yy, xx]:
                    lab[yy, xx] = n
                    stack.append((yy, xx))
        out.append((np.array(ry), np.array(rx)))
    return out


def _gap_alpha_auto(a, mask, gaps):
    """AS5aR2 (KRITIK-5a2 K4; A-22 keeps cut_fill and the scissor at 0.5): one gap alpha per railing chart, chosen
    from CUT_FILL_ALPHAS so that the share of the chart passing the alpha test in the box-filtered mips 1 - 4 (the
    engine's Image.generate_mipmaps, 8 bit) stays nearest to mip 0. A fixed 0.4 closed the Haussmann balconies to
    2.7 times their coverage at mip 4 (dark bands from 75 m), 0.3 made the Lyon window guards vanish there: the
    right value depends on how much of the chart the bars cover. Every value is below the scissor, so mip 0 shows
    the bars as before. In place; returns {alpha: charts}."""
    chosen = {}
    h, w = a.shape
    for ry, rx in _components(mask):
        if ry.size < 64:
            continue
        y0, y1 = (int(ry.min()) // 16) * 16, min(h, (int(ry.max()) // 16 + 1) * 16)
        x0, x1 = (int(rx.min()) // 16) * 16, min(w, (int(rx.max()) // 16 + 1) * 16)
        sub = a[y0:y1, x0:x1]
        reg = np.zeros(sub.shape, dtype=bool)
        reg[ry - y0, rx - x0] = True
        gap = reg & gaps[y0:y1, x0:x1]
        if not gap.any():
            continue
        c0 = float((sub[reg] >= 0.5).mean())
        if c0 <= 0.0:
            continue
        best = None
        for gv in CUT_FILL_ALPHAS:
            lv = np.where(gap, gv, sub)
            lv = np.round(lv * 255.0)
            rg = reg.astype(np.float64)
            err = 0.0
            for k, wk in enumerate(CUT_FILL_MIPS):
                hh, ww = lv.shape
                if hh < 2 or ww < 2:
                    break
                hh, ww = hh // 2 * 2, ww // 2 * 2
                lv = np.floor((lv[:hh, :ww].reshape(hh // 2, 2, ww // 2, 2).sum(axis=(1, 3)) + 2.0) / 4.0)
                rg = rg[:hh, :ww].reshape(hh // 2, 2, ww // 2, 2).mean(axis=(1, 3))
                inside = rg >= 0.5
                if not inside.any():
                    break
                ck = float((lv[inside] >= 127.5).mean())
                err += wk * abs(math.log(max(ck, 0.03) / c0))
            if best is None or err < best[0] - 1e-9:
                best = (err, gv)
        a[y0:y1, x0:x1] = np.where(gap, best[1], sub)
        chosen[best[1]] = chosen.get(best[1], 0) + 1
    return {str(k): v for k, v in sorted(chosen.items())}



