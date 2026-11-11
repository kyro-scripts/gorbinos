"""Hyperreal cut-outs: photo-real bits snipped out of a magazine and pasted
into the cartoon world (the FISH collage look). Everything is painted
procedurally - height fields lit like a studio photo, with pores, veins,
fibres and wet highlights - then given a white scissor-cut paper border.

  hr_eye.png, hr_eye_b.png   human eye, blue / brown iris; 7 frames:
                             centre, left, right, rolled up, half shut,
                             shut, wide
  hr_eye_sore.png            the blue eye, bloodshot and puffy (same frames)
  hr_mouth.png               human lips; 4 frames: shut, open, screaming, grin
  hr_nose.png                a human nose
  hr_eyeball.png             a loose eyeball trailing its nerve
  hr_tooth.png               a pulled molar
  hr_fish.png                a trout
  hr_meat.png                a raw steak
  ../ui/hud_meat.png         a strip of raw meat (the health bar)
  ../ui/hud_scales.png       a strip of fish skin (the armor bar)

Run: python3 tools/gen_hyperreal.py
"""
import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage
from texlib import ROOT

OUT = os.path.join(ROOT, "assets", "sprites")
UI_OUT = os.path.join(ROOT, "assets", "ui")
SS = 2          # supersampling
PAPER = np.array([0.975, 0.955, 0.9])
LIGHT = np.array([-0.45, -0.6, 0.66])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


# ------------------------------------------------------------------ basics
def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def mix(a, b, t):
    t = np.asarray(t)
    if t.ndim == 2 and np.ndim(a) >= 1 and np.shape(a)[-1:] == (3,):
        t = t[..., None]
    elif t.ndim == 2 and np.ndim(b) >= 1 and np.shape(b)[-1:] == (3,):
        t = t[..., None]
    return np.asarray(a) * (1.0 - t) + np.asarray(b) * t


def noise(shape, cells, seed, octaves=4, persist=0.5):
    """Smooth value noise (fbm) in 0..1 over an array of the given shape."""
    r = np.random.default_rng(seed)
    h, w = shape
    out = np.zeros(shape, np.float32)
    amp = 1.0
    tot = 0.0
    c = cells
    for o in range(octaves):
        gh = max(2, int(round(h / max(h, w) * c)) + 2)
        gw = max(2, int(round(w / max(h, w) * c)) + 2)
        g = r.random((gh, gw)).astype(np.float32)
        z = ndimage.zoom(g, (h / (gh - 1) * 1.02, w / (gw - 1) * 1.02), order=3)[:h, :w]
        if z.shape != shape:
            z = np.pad(z, ((0, h - z.shape[0]), (0, w - z.shape[1])), mode="edge")
        out += z * amp
        tot += amp
        amp *= persist
        c *= 2
    out /= tot
    lo, hi = np.percentile(out, 1), np.percentile(out, 99)
    return np.clip((out - lo) / (hi - lo + 1e-6), 0, 1)


def grid(w, h, xr, yr=1.0):
    """Pixel grid in model units: x in [-xr, xr], y in [-yr, yr] (y down)."""
    xs = np.linspace(-xr, xr, w, dtype=np.float32)
    ys = np.linspace(-yr, yr, h, dtype=np.float32)
    return np.meshgrid(xs, ys)


def normals(hf, strength, px):
    """Surface normals of a height field (height in model units, px = model
    units per pixel)."""
    gy, gx = np.gradient(hf * strength, px)
    n = np.stack([-gx, -gy, np.ones_like(hf)], -1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def light(n, albedo, wrap=0.35, ambient=0.18, spec=0.0, power=30.0, spec_map=None, spec_col=(1, 1, 1)):
    d = np.clip((np.tensordot(n, LIGHT, 1) + wrap) / (1 + wrap), 0, 1)
    col = albedo * (ambient + (1 - ambient) * d)[..., None]
    if spec > 0:
        hv = LIGHT + np.array([0, 0, 1.0])
        hv /= np.linalg.norm(hv)
        s = np.clip(np.tensordot(n, hv, 1), 0, 1) ** power * spec
        if spec_map is not None:
            s = s * spec_map
        col = col + s[..., None] * np.array(spec_col)
    return col


def ao(hf, radius_px, k):
    """Cheap ambient occlusion: darker where lower than the surroundings."""
    blur = ndimage.gaussian_filter(hf, radius_px)
    return np.clip(1.0 - np.maximum(blur - hf, 0) * k, 0.3, 1.0)


def to_img(rgb, alpha):
    rgb = np.clip(rgb, 0, 1)
    a = np.clip(alpha, 0, 1)
    arr = np.concatenate([rgb, a[..., None]], -1)
    return Image.fromarray((arr * 255 + 0.5).astype(np.uint8), "RGBA")


def polygon_mask(w, h, pts):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).polygon([tuple(p) for p in pts], fill=255)
    return np.asarray(m).astype(np.float32) / 255.0


def scissor_shape(w, h, cx, cy, rx, ry, n, seed, jit=0.08):
    """A rough hand-cut outline: a polygon round an ellipse, a few straight
    snips with slight wobble."""
    r = np.random.default_rng(seed)
    pts = []
    a0 = r.random() * math.tau
    for k in range(n):
        a = a0 + k / n * math.tau + r.uniform(-0.2, 0.2) / n * math.tau
        f = 1.0 + r.uniform(-jit, jit)
        pts.append((cx + math.cos(a) * rx * f, cy + math.sin(a) * ry * f))
    return polygon_mask(w, h, pts)


def paper_border(img, border, seed, shadow=(3, 4)):
    """White scissor-cut paper border round the opaque part, a hard shadow
    under it (the snipped-from-a-magazine look)."""
    r = np.random.default_rng(seed)
    a = np.asarray(img.split()[3]).astype(np.float32) / 255.0
    m = a > 0.5
    # grow the shape by the border, then snip the edge into straight-ish cuts
    grown = ndimage.binary_dilation(m, iterations=border)
    soft = ndimage.gaussian_filter(grown.astype(np.float32), 1.2)
    wob = noise(a.shape, 6, seed + 9, 2) - 0.5
    g = np.clip((soft - 0.5 + wob * 0.25) * 6 + 0.5, 0, 1)
    g = np.maximum(g, a)
    w, h = img.size
    paper = np.zeros((h, w, 4), np.float32)
    fib = noise((h, w), 60, seed + 3, 2)
    paper[..., :3] = PAPER * (0.96 + 0.04 * fib[..., None])
    paper[..., 3] = g
    sh = np.zeros((h, w, 4), np.float32)
    sx, sy = shadow
    gs = np.zeros_like(g)
    gs[sy:, sx:] = g[:h - sy, :w - sx]
    sh[..., :3] = (0.08, 0.0, 0.1)
    sh[..., 3] = gs * 0.55
    out = Image.alpha_composite(Image.fromarray((sh * 255).astype(np.uint8), "RGBA"),
                                Image.fromarray((paper * 255).astype(np.uint8), "RGBA"))
    return Image.alpha_composite(out, img)


def finish(rgb, alpha, size, border, seed, shadow=(3, 4)):
    """Downsample from the supersampled canvas and give it its paper border."""
    img = to_img(rgb, alpha).resize(size, Image.LANCZOS)
    return paper_border(img, border, seed, shadow)


def strokes(w, h, lines, color, scale):
    """Draw tapering hair strokes (lashes, brows) on an RGBA layer.
    lines: list of (points[(x,y) model], width0, width1, alpha)."""
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for pts, w0, w1, a in lines:
        n = len(pts) - 1
        for i in range(n):
            t = i / max(n - 1, 1)
            wd = max(1, int(round(w0 + (w1 - w0) * t)))
            col = tuple(int(c * 255) for c in color) + (int(255 * a * (1 - 0.35 * t)),)
            d.line([scale(pts[i]), scale(pts[i + 1])], fill=col, width=wd)
    return np.asarray(layer).astype(np.float32) / 255.0


def over(rgb, layer):
    a = layer[..., 3:4]
    return rgb * (1 - a) + layer[..., :3] * a


def veins(w, h, starts, seed, count, scale, width=(1, 3), alpha=(0.3, 0.7), col=(0.62, 0.08, 0.1), toward=(0, 0), length=0.9):
    """Branching red veins from start points, wandering toward a point."""
    r = np.random.default_rng(seed)
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    def walk(x, y, ang, ln, wd, a, depth):
        steps = int(ln / 0.03)
        for i in range(steps):
            ang += r.normal(0, 0.35)
            # bend toward the target a little
            ta = math.atan2(toward[1] - y, toward[0] - x)
            ang += (((ta - ang + math.pi) % math.tau) - math.pi) * 0.08
            nx, ny = x + math.cos(ang) * 0.03, y + math.sin(ang) * 0.03
            ww = max(1, int(round(wd * (1 - i / steps * 0.7))))
            d.line([scale((x, y)), scale((nx, ny))], fill=(int(col[0] * 255), int(col[1] * 255), int(col[2] * 255), int(a * 255 * (1 - i / steps * 0.6))), width=ww)
            x, y = nx, ny
            if depth < 3 and r.random() < 0.09:
                walk(x, y, ang + r.choice([-1, 1]) * r.uniform(0.5, 1.1), ln * 0.45, wd * 0.6, a * 0.8, depth + 1)

    for k in range(count):
        sx, sy = starts[k % len(starts)]
        sx += r.uniform(-0.05, 0.05)
        sy += r.uniform(-0.25, 0.25)
        ang = math.atan2(toward[1] - sy, toward[0] - sx) + r.uniform(-0.6, 0.6)
        walk(sx, sy, ang, length * r.uniform(0.4, 1.0), r.uniform(*width), r.uniform(*alpha), 0)
    arr = np.asarray(layer.filter(ImageFilter.GaussianBlur(0.6))).astype(np.float32) / 255.0
    return arr


# ------------------------------------------------------------------ eye
IRIS = {
    "blue": [(0.62, 0.6, 0.42), (0.36, 0.52, 0.7), (0.2, 0.33, 0.5), (0.06, 0.08, 0.12)],
    "brown": [(0.55, 0.36, 0.14), (0.38, 0.22, 0.09), (0.24, 0.13, 0.06), (0.06, 0.04, 0.03)],
}


def eye_frame(gaze=(0.0, 0.0), open_k=1.0, sore=0.0, iris="blue", seed=1):
    W, H = 384 * SS, 240 * SS
    XR = 1.6
    x, y = grid(W, H, XR)
    px = 2 * XR / W
    t = x / 1.0

    def lid_curves(o):
        tt = np.clip(t, -1, 1)
        base_u = -0.56 * (1 - tt ** 2) ** 0.75 * (1 - 0.12 * tt)
        base_l = 0.34 * (1 - tt ** 2) ** 0.85 * (1 + 0.12 * tt)
        dip = 0.07 * np.exp(-((t + 1.0) / 0.18) ** 2)
        # in a blink the upper lid comes down to meet the lower one
        closed = base_l * 0.82
        if o >= 1.0:
            up = base_u * (1 + (o - 1) * 1.1)
            lo = base_l * (1 + (o - 1) * 0.35)
        else:
            up = closed * (1 - o) + base_u * o
            lo = closed * (1 - o) + base_l * o
            if o <= 0.0:
                up = closed - 0.004
                lo = closed + 0.004
        return up + dip, lo + dip

    up, lo = lid_curves(open_k)
    inside = (np.abs(t) < 1.0) & (y > up) & (y < lo)
    # antialiased opening
    edge = np.minimum(y - up, lo - y)
    open_m = np.clip(edge / (px * 1.5), 0, 1) * (np.abs(t) < 1.0) * (open_k > 0.0)

    # ---- eyeball
    rb = 1.2
    bz = np.sqrt(np.clip(1 - (x ** 2 + (y + 0.05) ** 2) / rb ** 2, 0, 1))
    sclera = np.array([0.95, 0.91, 0.87]) * (0.5 + 0.5 * bz)[..., None]
    corner = smooth(0.45, 1.0, np.abs(x))
    sclera = mix(sclera, np.array([0.9, 0.62, 0.6]) * (0.6 + 0.4 * bz)[..., None], corner * (0.45 + 0.35 * sore))
    sclera = mix(sclera, np.array([0.95, 0.66, 0.64]) * (0.55 + 0.45 * bz)[..., None], sore * 0.45)
    sn = noise((H, W), 12, seed + 1, 3)
    sclera *= (0.95 + 0.08 * sn)[..., None]

    # ---- iris
    gx, gy = gaze
    icx, icy = gx * 0.48, -0.06 + gy * 0.4
    ri = 0.42
    dx, dy = x - icx, y - icy
    # foreshortened when it looks aside
    fx = 1.0 + abs(gx) * 0.25
    d = np.sqrt((dx * fx) ** 2 + dy ** 2) / ri
    th = np.arctan2(dy, dx)
    rr = np.random.default_rng(seed + 5)
    # radial fibres: noise along the angle, stretched along the radius
    ang_n = np.zeros_like(d)
    for f, a in [(48, 0.45), (110, 0.3), (230, 0.25)]:
        ph = rr.random(f) * math.tau
        amp = rr.random(f)
        k = np.linspace(0, 1, f, endpoint=False)
        idx = ((th / math.tau + 0.5) * f).astype(np.int32) % f
        frac = (th / math.tau + 0.5) * f - np.floor((th / math.tau + 0.5) * f)
        v0 = amp[idx]
        v1 = amp[(idx + 1) % f]
        ang_n += (v0 + (v1 - v0) * (frac * frac * (3 - 2 * frac))) * a
    wav = noise((H, W), 30, seed + 7, 2)
    fib = np.clip(ang_n * (0.8 + 0.4 * np.sin(d * 18 + wav * 6)), 0, 1.4)
    c_in, c_mid, c_out, c_ring = [np.array(c) for c in IRIS[iris]]
    icol = mix(c_in, c_mid, smooth(0.3, 0.58, d))
    icol = mix(icol, c_out, smooth(0.62, 0.95, d))
    icol = icol * (0.55 + 0.75 * fib)[..., None]
    crypt = (noise((H, W), 26, seed + 11, 2) > 0.72) & (d > 0.45) & (d < 0.85)
    icol = mix(icol, icol * 0.7, crypt * 0.5)
    # collarette: a crinkled lighter ring round the pupil
    col_r = 0.48 + 0.05 * np.sin(th * 9 + wav * 4)
    icol = mix(icol, c_in * 1.25, np.exp(-((d - col_r) / 0.05) ** 2) * 0.5)
    icol = mix(icol, c_ring, smooth(0.84, 1.0, d))
    # light comes in on the far side of the iris
    glow = smooth(0.35, 0.9, d) * (1 - smooth(0.9, 1.0, d)) * np.clip((dx * 0.7 + dy * 0.7) / ri, 0, 1)
    icol += glow[..., None] * 0.35 * c_mid
    rp = 0.15
    pupil = 1 - smooth(rp / ri - 0.03, rp / ri + 0.02, d)
    icol = mix(icol, np.array([0.015, 0.012, 0.018]), pupil)
    iris_m = 1 - smooth(0.97, 1.03, d)

    eye = mix(sclera, icol, iris_m)
    # veins over the white
    scale = lambda p: (int((p[0] + XR) / (2 * XR) * W), int((p[1] + 1) / 2 * H))
    vl = veins(W, H, [(-0.95, 0.05), (0.97, 0.06), (0.0, 0.25), (0.6, -0.2)], seed + 20, int(16 + sore * 40), scale,
               width=(1, 2.5 + sore * 2), alpha=(0.25 + sore * 0.2, 0.55 + sore * 0.3), toward=(icx, icy), length=0.7)
    vl[..., 3] *= (1 - iris_m) * (0.6 + 0.4 * corner)
    eye = over(eye, vl)
    # caruncle in the inner corner
    car = np.exp(-(((x + 0.9) / 0.11) ** 2 + ((y - 0.06) / 0.1) ** 2))
    eye = mix(eye, np.array([0.86, 0.48, 0.48]) * (0.7 + 0.3 * sn)[..., None], np.clip(car * 1.6, 0, 1))
    # shadow under the upper lid and its lashes, a wet line on the lower lid
    lidsh = 1 - 0.6 * np.exp(-np.clip(y - up, 0, None) / 0.13)
    eye = eye * lidsh[..., None]
    eye = eye * (1 - 0.18 * np.exp(-np.clip(lo - y, 0, None) / 0.05))[..., None]
    tear = np.exp(-((lo - y - 0.03) / 0.012) ** 2) * (noise((H, W), 40, seed + 31, 2) > 0.35)
    eye = mix(eye, np.array([1.0, 0.96, 0.96]), tear * 0.55)
    # catchlight: a window reflected in the cornea, and a smaller second one
    wx, wy = x - icx + 0.15, y - icy + 0.14
    cl = smooth(0.045, 0.028, np.maximum(np.abs(wx) * 0.85, np.abs(wy)))
    cl *= 1 - 0.55 * (np.abs(wx) < 0.006) - 0.55 * (np.abs(wy) < 0.005)   # window bars
    cl = np.clip(cl, 0, 1) * (0.75 + 0.25 * smooth(0.06, -0.04, wx + wy))
    cl2 = smooth(0.03, 0.015, np.sqrt((x - icx - 0.17) ** 2 + (y - icy - 0.12) ** 2))
    sheen = np.exp(-(((x - icx + 0.1) / 0.3) ** 2 + ((y - icy + 0.12) / 0.2) ** 2)) * 0.12
    eye = eye + (cl * 0.95 + cl2 * 0.6 + sheen)[..., None] * (y > up + 0.02)[..., None]

    # ---- skin round it
    hf = np.zeros_like(x)
    uc, lc = up, lo
    above = uc - y      # > 0 above the upper lid edge
    below = y - lc      # > 0 below the lower lid edge
    span = smooth(1.3, 0.95, np.abs(t))
    lid_band = smooth(0.0, 0.12, above) * (1 - smooth(0.22, 0.44, above))
    hf += 0.16 * lid_band * span
    crease_y = 0.38 + 0.05 * (1 - open_k)
    hf -= 0.09 * np.exp(-((above - crease_y) / 0.07) ** 2) * smooth(1.4, 0.5, np.abs(t))
    hf += 0.35 * smooth(0.5, 1.05, above) * smooth(1.7, 0.2, np.abs(x + 0.1))   # brow bone
    hf += (0.09 + sore * 0.08) * smooth(0.0, 0.07, below) * (1 - smooth(0.1, 0.26, below)) * span
    hf -= 0.07 * np.exp(-((below - 0.3) / 0.1) ** 2) * smooth(1.3, 0.2, np.abs(t + 0.2))  # tear trough
    hf += 0.25 * smooth(0.35, 1.0, below)       # cheek
    hf -= 0.12 * np.exp(-np.clip(np.minimum(above, below), 0, None) / 0.06) * span      # into the socket
    # lid rims
    hf += 0.03 * np.exp(-(above / 0.03) ** 2) * span + 0.025 * np.exp(-(below / 0.025) ** 2) * span
    # crow's feet and fine lid lines, faint
    cdist = np.sqrt((x - 1.1) ** 2 + (y * 1.3) ** 2)
    ca = np.arctan2(y, x - 1.1) + (noise((H, W), 10, seed + 41, 2) - 0.5) * 0.5
    hf += 0.0035 * np.sin(ca * 22) * smooth(0.08, 0.25, cdist) * smooth(0.6, 0.25, cdist) * smooth(0.85, 1.05, x)
    hf += 0.0025 * np.sin(y * 150 + noise((H, W), 10, seed + 42, 2) * 9) * smooth(0.02, 0.1, below) * smooth(0.4, 0.15, below) * span
    hf += 0.002 * np.sin(y * 130 + noise((H, W), 10, seed + 43, 2) * 9) * smooth(0.12, 0.2, above) * smooth(0.6, 0.3, above) * span
    pores = noise((H, W), 260, seed + 50, 1)
    hf += 0.02 * noise((H, W), 16, seed + 51, 3) + 0.0035 * pores + 0.002 * noise((H, W), 120, seed + 52, 2)
    n = normals(hf, 1.0, px)
    skin = np.array([0.88, 0.66, 0.56])
    mott = noise((H, W), 14, seed + 60, 4)
    alb = skin * (0.92 + 0.12 * mott)[..., None]
    alb = mix(alb, np.array([0.86, 0.55, 0.52]), (0.5 + sore * 0.4) * np.exp(-np.clip(np.minimum(above, below), 0, None) / 0.12) * span)
    alb = mix(alb, np.array([0.66, 0.5, 0.52]), np.exp(-((below - 0.28) / 0.12) ** 2) * (0.35 + 0.35 * sore))
    alb = mix(alb, np.array([0.8, 0.46, 0.44]), np.exp(-(np.minimum(np.abs(above), np.abs(below)) / 0.025) ** 2) * 0.8 * smooth(1.08, 0.92, np.abs(t)))
    alb *= (1 - 0.06 * (pores > 0.8))[..., None]
    skin_rgb = light(n, alb, spec=0.22, power=24, spec_map=0.5 + 0.5 * noise((H, W), 50, seed + 61, 2))
    skin_rgb *= ao(hf, 18, 1.6)[..., None]
    # light scattering under the skin: the shadows go warm, not grey
    lum = skin_rgb.mean(-1, keepdims=True)
    skin_rgb = skin_rgb + (1 - np.clip(lum * 1.6, 0, 1)) * np.array([0.07, 0.0, -0.02])

    rgb = mix(skin_rgb, eye, open_m)

    # ---- lashes
    r = np.random.default_rng(seed + 70)
    lines = []
    closedish = open_k < 0.35
    for k in range(80):
        tt = r.uniform(-0.82, 1.02)
        uu, ll = lid_curves(open_k)
        yi = int(np.clip((0 + 1) / 2 * H, 0, H - 1))
        xi = int(np.clip((tt + XR) / (2 * XR) * (W - 1), 0, W - 1))
        rx = tt
        ry = float(uu[0, xi] if np.ndim(uu) == 2 else uu) - 0.005
        ry = float(up[yi, xi]) - 0.01
        ln = r.uniform(0.15, 0.28) * (0.6 + 0.5 * smooth(-0.8, 0.6, np.array(tt)))
        side = 0.35 + tt * 0.45
        pts = [(rx, ry)]
        if closedish:
            ang = math.atan2(1.0, side * 0.6)
            curl = -0.03
        else:
            ang = math.atan2(-0.9 + 0.3 * abs(tt), side)
            curl = -0.04 * (1 if side > 0 else -1)
        for s in range(6):
            ang += curl + r.normal(0, 0.03)
            pts.append((pts[-1][0] + math.cos(ang) * ln / 6, pts[-1][1] + math.sin(ang) * ln / 6))
        lines.append((pts, 3.2, 1.0, 0.95))
    if not closedish:
        for k in range(24):
            tt = r.uniform(-0.5, 0.95)
            xi = int(np.clip((tt + XR) / (2 * XR) * (W - 1), 0, W - 1))
            ry = float(lo[H // 2, xi]) + 0.012
            ln = r.uniform(0.05, 0.1)
            ang = math.atan2(0.8, 0.5 + tt * 0.9)
            pts = [(tt, ry)]
            for s in range(4):
                ang += r.normal(0, 0.05)
                pts.append((pts[-1][0] + math.cos(ang) * ln / 4, pts[-1][1] + math.sin(ang) * ln / 4))
            lines.append((pts, 1.6, 1.0, 0.45))
    ll = strokes(W, H, lines, (0.07, 0.045, 0.035), scale)
    rgb = over(rgb, ll)

    alpha = scissor_shape(W, H, W * 0.5, H * 0.52, W * 0.465, H * 0.445, 11, seed + 90, 0.07)
    return rgb, alpha


EYE_FRAMES = [((0, 0), 1.0), ((-0.85, 0.05), 1.0), ((0.85, 0.05), 1.0), ((0.1, -0.95), 1.05),
              ((0, 0.25), 0.45), ((0, 0), 0.0), ((0, 0), 1.3)]


def eye_atlas(name, iris, sore, seed):
    frames = []
    for (g, o) in EYE_FRAMES:
        rgb, a = eye_frame(g, o, sore, iris, seed)
        frames.append(finish(rgb, a, (384, 240), 6, seed + 3))
    atlas = Image.new("RGBA", (384 * len(frames), 240), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        atlas.paste(f, (i * 384, 0))
    atlas.save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


def cast_shadow(hf, px, steps=28, step_px=3.0, soft=0.04):
    """Shadows the height field casts on itself, marching toward the light."""
    h, w = hf.shape
    lxy = LIGHT[:2] / np.linalg.norm(LIGHT[:2])
    rise = LIGHT[2] / np.linalg.norm(LIGHT[:2])      # height gained per unit along the light
    sh = np.zeros_like(hf)
    for i in range(1, steps + 1):
        dx = int(round(lxy[0] * step_px * i))
        dy = int(round(lxy[1] * step_px * i))
        shifted = np.full_like(hf, -1e9)
        ys0, ys1 = max(0, -dy), min(h, h - dy)
        xs0, xs1 = max(0, -dx), min(w, w - dx)
        shifted[ys0:ys1, xs0:xs1] = hf[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx]
        dist = math.hypot(dx, dy) * px
        occ = (shifted - (hf + dist * rise)) / soft
        sh = np.maximum(sh, np.clip(occ, 0, 1))
    return 1.0 - sh


def skin_albedo(shape, seed, base=(0.88, 0.66, 0.56)):
    mott = noise(shape, 14, seed, 4)
    red = noise(shape, 6, seed + 1, 3)
    alb = np.array(base) * (0.92 + 0.12 * mott)[..., None]
    return mix(alb, np.array([0.86, 0.52, 0.5]), smooth(0.55, 0.95, red) * 0.35)


def warm_shadows(rgb):
    lum = rgb.mean(-1, keepdims=True)
    return rgb + (1 - np.clip(lum * 1.6, 0, 1)) * np.array([0.07, 0.0, -0.02])


# ------------------------------------------------------------------ mouth
def mouth_frame(open_k=0.0, grin=0.0, seed=5):
    W, H = 384 * SS, 240 * SS
    XR = 1.6
    x, y = grid(W, H, XR)
    px = 2 * XR / W
    hw = 0.95 + 0.18 * grin
    t = np.clip(x / hw, -1.2, 1.2)
    tc = np.clip(t, -1, 1)
    ym = 0.05 - 0.13 * grin * tc ** 2 + 0.02 * tc ** 2
    oh = open_k * 0.62 * (1 - tc ** 2) ** 0.7 + grin * 0.2 * (1 - tc ** 2) ** 0.5
    o_top = ym - oh * 0.38
    o_bot = ym + oh * 0.62
    th_u = (0.2 * (1 - tc ** 2) ** 0.6 + 0.05 * np.exp(-((np.abs(tc) - 0.17) / 0.09) ** 2) - 0.03 * np.exp(-(tc / 0.06) ** 2)) * (1 - 0.4 * grin) * (1 - 0.25 * open_k)
    th_l = 0.3 * (1 - tc ** 2) ** 0.55 * (1 - 0.35 * grin) * (1 - 0.2 * open_k)
    l_top = o_top - th_u
    l_bot = o_bot + th_l
    span = smooth(1.02, 0.94, np.abs(t))
    up_lip = (y > l_top) & (y < o_top + 0.002)
    lo_lip = (y < l_bot) & (y > o_bot - 0.002)
    aa = lambda d: np.clip(d / (px * 1.5), 0, 1)
    up_m = aa(np.minimum(y - l_top, o_top - y + 0.004)) * span
    lo_m = aa(np.minimum(l_bot - y, y - o_bot + 0.004)) * span
    in_m = aa(np.minimum(y - o_top, o_bot - y)) * span * (oh > 0.004)

    # ---- height
    hf = np.zeros_like(x)
    u_u = np.clip((o_top - y) / np.maximum(th_u, 1e-3), 0, 1)
    u_l = np.clip((y - o_bot) / np.maximum(th_l, 1e-3), 0, 1)
    wr = noise((H, W), 10, seed + 3, 2)
    wrinkle = np.abs(np.sin(x * 70 + wr * 7)) ** 0.5
    hf += up_m * (0.1 * np.sin(np.pi * u_u ** 0.75) - 0.008 * wrinkle * np.sin(np.pi * u_u))
    hf += lo_m * (0.14 * np.sin(np.pi * u_l ** 0.7) - 0.01 * wrinkle * np.sin(np.pi * u_l))
    # philtrum, nasolabial folds, the groove over the chin, the chin
    above = l_top - y
    ph = smooth(0.0, 0.08, above) * smooth(1.0, 0.4, above)
    hf += ph * (0.018 * (np.exp(-((x - 0.13) / 0.07) ** 2) + np.exp(-((x + 0.13) / 0.07) ** 2)) - 0.01 * np.exp(-(x / 0.08) ** 2))
    for sx in (-1, 1):
        cx = sx * (1.05 + 0.25 * grin) + sx * 0.25 * (-y - 0.2)
        hf -= 0.05 * np.exp(-((x - cx) / (0.07 + 0.03 * grin)) ** 2) * smooth(0.6, -0.1, y) * smooth(-1.0, -0.5, y)
        # cheeks bunch up in a grin
        hf += 0.12 * grin * np.exp(-(((x - sx * 1.25) / 0.3) ** 2 + ((y + 0.25) / 0.35) ** 2))
    below = y - l_bot
    hf -= 0.05 * np.exp(-((below - 0.12) / 0.07) ** 2) * smooth(0.9, 0.2, np.abs(x))
    hf += 0.2 * smooth(0.15, 0.7, below) * smooth(1.2, 0.3, np.abs(x))
    # mouth corners
    for sx in (-1, 1):
        hf -= 0.05 * np.exp(-(((x - sx * hw * 1.0) / 0.06) ** 2 + ((y - ym) / 0.05) ** 2))
    hf += 0.02 * noise((H, W), 16, seed + 4, 3) + 0.003 * noise((H, W), 260, seed + 5, 1)
    hf = hf - in_m * 0.15

    n = normals(hf, 1.0, px)
    skin = skin_albedo((H, W), seed + 10)
    # a shadow of stubble
    stub = (noise((H, W), 300, seed + 12, 1) > 0.86) & (np.abs(y - ym) > 0.25)
    skin = mix(skin, skin * 0.72, stub * 0.35)
    lipc = np.array([0.76, 0.4, 0.42]) * (0.93 + 0.1 * noise((H, W), 20, seed + 13, 2))[..., None]
    lipc = mix(lipc, np.array([0.62, 0.26, 0.3]), np.clip(1 - u_u * 2.5, 0, 1) * up_m + np.clip(1 - u_l * 2.5, 0, 1) * lo_m)
    lipc = lipc * (1 - 0.12 * wrinkle)[..., None]
    lip_m = np.clip(up_m + lo_m, 0, 1)
    alb = mix(skin, lipc, lip_m)
    # the vermilion border is a touch paler
    vb = np.exp(-(np.minimum(np.abs(y - l_top), np.abs(y - l_bot)) / 0.015) ** 2) * span
    alb = mix(alb, alb * 1.12 + 0.02, vb * 0.5)
    spec_map = lip_m * (0.6 + 0.8 * noise((H, W), 60, seed + 14, 2) * (1 - 0.7 * wrinkle)) + (1 - lip_m) * 0.25
    rgb = light(n, alb, spec=0.55, power=38, spec_map=spec_map)
    rgb *= ao(hf, 16, 1.4)[..., None]
    rgb *= cast_shadow(hf, px, 20, 2.0, 0.03)[..., None] * 0.35 + 0.65
    rgb = warm_shadows(rgb)

    # ---- inside: dark, teeth, gums, tongue
    if open_k > 0 or grin > 0:
        depth = np.clip(np.minimum(y - o_top, o_bot - y) / np.maximum(oh * 0.5, 1e-3), 0, 1)
        inside = mix(np.array([0.32, 0.08, 0.09]), np.array([0.06, 0.01, 0.02]), smooth(0.0, 0.7, depth))
        inside = inside * (1 - 0.5 * smooth(0.6, 1.0, np.abs(tc)))[..., None]
        r = np.random.default_rng(seed + 20)
        widths = [0.17, 0.13, 0.12, 0.11, 0.11, 0.1]
        tooth = np.zeros_like(x)
        tcol = np.zeros(x.shape + (3,))
        gum_y = o_top - 0.03 + (0.06 if grin > 0 else 0.0)
        for row, (ty, tlen, wk) in enumerate([(gum_y, 0.2 if grin == 0 else 0.13 + oh.max() * 0.0, 1.0),
                                               (o_bot + 0.03, -0.14, 0.82)]):
            if row == 1 and open_k < 0.5 and grin == 0:
                continue
            for sx in (-1, 1):
                cx = 0.0
                for k, wd in enumerate(widths):
                    wd *= wk
                    xc = sx * (cx + wd * 0.5)
                    cx += wd + 0.008
                    ln = abs(tlen) * (1 - 0.1 * k) * (1.0 if grin == 0 else 1.0)
                    if grin > 0:
                        ln = abs(ym - ty) + 0.004 if row == 0 else abs(ty - ym) + 0.004
                    yy = (y - ty) / ln if tlen > 0 or grin > 0 and row == 0 else (ty - y) / ln
                    if row == 1 and grin > 0:
                        yy = (ty - y) / ln
                    lx = (x - xc) / (wd * 0.5)
                    shape = (np.abs(lx) < 1) & (yy > 0) & (yy < 1 - 0.25 * lx ** 2)
                    sm = shape.astype(np.float32)
                    tooth = np.maximum(tooth, sm)
                    bulge = np.sqrt(np.clip(1 - lx ** 2, 0, 1))
                    c = np.array([0.94, 0.91, 0.82]) * (0.55 + 0.45 * bulge)[..., None]
                    c = mix(c, np.array([0.86, 0.8, 0.62]) * (0.55 + 0.45 * bulge)[..., None], smooth(0.4, 0.0, yy) * 0.5)
                    c = mix(c, np.array([0.7, 0.74, 0.8]) * (0.6 + 0.4 * bulge)[..., None], smooth(0.75, 1.0, yy) * 0.45)
                    c = c * (1 - 0.35 * smooth(0.4, 1.0, k / 5.0))
                    spec = smooth(0.85, 1.0, bulge) * smooth(0.1, 0.3, yy) * 0.35
                    c = c + spec[..., None]
                    tcol = np.where(shape[..., None], c, tcol)
        gum = (y > o_top - 0.01) & (y < gum_y + 0.03) & (in_m > 0)
        inside = mix(inside, np.array([0.82, 0.42, 0.46]) * (0.7 + 0.3 * noise((H, W), 30, seed + 22, 2))[..., None], gum * 0.9)
        if open_k > 0.5:
            tg = np.exp(-(((x) / 0.55) ** 2 + ((y - o_bot + 0.05) / 0.2) ** 2))
            tongue = np.array([0.78, 0.36, 0.42]) * (0.75 + 0.35 * noise((H, W), 50, seed + 23, 2))[..., None]
            tongue = tongue * (1 - 0.3 * np.exp(-(x / 0.04) ** 2))[..., None] + (smooth(0.55, 0.9, tg) * 0.18)[..., None]
            inside = mix(inside, tongue, np.clip(tg * 2.2, 0, 1))
        inside = mix(inside, tcol, tooth)
        # the upper lip shades the top of the mouth
        inside = inside * (1 - 0.5 * np.exp(-np.clip(y - o_top, 0, None) / 0.06))[..., None]
        rgb = mix(rgb, inside, in_m * (1 - lip_m))

    alpha = scissor_shape(W, H, W * 0.5, H * 0.52, W * 0.47, H * 0.45, 11, seed + 90, 0.07)
    return rgb, alpha


MOUTH_FRAMES = [(0.0, 0.0), (0.32, 0.0), (0.85, 0.0), (0.0, 1.0)]


def mouth_atlas():
    frames = []
    for o, g in MOUTH_FRAMES:
        rgb, a = mouth_frame(o, g, 5)
        frames.append(finish(rgb, a, (384, 240), 6, 8))
    atlas = Image.new("RGBA", (384 * len(frames), 240), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        atlas.paste(f, (i * 384, 0))
    atlas.save(os.path.join(OUT, "hr_mouth.png"))
    print("wrote hr_mouth")


# ------------------------------------------------------------------ nose
def nose(seed=21):
    W = H = 256 * SS
    x, y = grid(W, H, 1.0)
    px = 2.0 / W
    hf = np.zeros_like(x)
    bw = 0.13 + 0.09 * smooth(-1.0, 0.3, y)
    hf += 0.42 * np.exp(-(x / bw) ** 2) * smooth(-1.15, -0.55, y) * smooth(0.55, 0.3, y)
    def blob(cx, cy, rx, ry, k):
        d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
        return k * np.sqrt(np.clip(1 - d, 0, 1))
    def soft_union(a, b, k=18.0):
        return np.log(np.exp(a * k) + np.exp(b * k)) / k
    tip = blob(0, 0.3, 0.3, 0.27, 0.42)
    hf = soft_union(hf, tip)
    for sx in (-1, 1):
        al = blob(sx * 0.27, 0.45, 0.2, 0.17, 0.26)
        hf = soft_union(hf, al)
        # the crease round each wing
        dd = np.sqrt(((x - sx * 0.27) / 0.21) ** 2 + ((y - 0.45) / 0.19) ** 2)
        hf -= 0.02 * np.exp(-((dd - 1.0) / 0.1) ** 2) * smooth(0.7, 0.5, y) * smooth(0.05, 0.2, np.abs(x))
    hf += 0.1 * smooth(0.3, 1.0, np.abs(x)) * smooth(0.9, -0.2, y)   # cheeks
    nostril = np.zeros_like(x)
    for sx in (-1, 1):
        a = 0.45 * sx
        xr = (x - sx * 0.15) * math.cos(a) + (y - 0.58) * math.sin(a)
        yr = -(x - sx * 0.15) * math.sin(a) + (y - 0.58) * math.cos(a)
        d = (xr / 0.1) ** 2 + (yr / 0.055) ** 2
        nostril = np.maximum(nostril, smooth(1.05, 0.7, d))
    hf -= nostril * 0.25
    hf += 0.018 * noise((H, W), 14, seed + 1, 3) + 0.004 * noise((H, W), 220, seed + 2, 1)
    pores = noise((H, W), 160, seed + 3, 1)
    hf -= 0.004 * (pores > 0.82) * smooth(0.6, 0.0, np.sqrt(x ** 2 + (y - 0.3) ** 2))
    n = normals(hf, 1.0, px)
    alb = skin_albedo((H, W), seed + 10)
    red = np.exp(-((x / 0.35) ** 2 + ((y - 0.32) / 0.3) ** 2)) * 0.5 + sum(np.exp(-(((x - sx * 0.3) / 0.2) ** 2 + ((y - 0.42) / 0.2) ** 2)) for sx in (-1, 1)) * 0.4
    alb = mix(alb, np.array([0.9, 0.5, 0.48]), np.clip(red, 0, 0.6))
    alb = mix(alb, np.array([0.18, 0.05, 0.05]), nostril)
    alb *= (1 - 0.1 * (pores > 0.82))[..., None]
    sm = 0.4 + 0.9 * np.exp(-((x / 0.2) ** 2 + ((y - 0.2) / 0.2) ** 2)) + 0.3 * np.exp(-((x / 0.1) ** 2 + ((y + 0.2) / 0.5) ** 2))
    rgb = light(n, alb, spec=0.35, power=32, spec_map=sm * (0.6 + 0.6 * noise((H, W), 80, seed + 4, 1)))
    rgb *= ao(hf, 20, 1.5)[..., None]
    rgb *= (cast_shadow(hf, px, 30, 3.0, 0.03) * 0.55 + 0.45)[..., None]
    rgb = warm_shadows(rgb)
    pts = [(0.38 * W, 0.02 * H), (0.62 * W, 0.03 * H), (0.78 * W, 0.42 * H), (0.98 * W, 0.66 * H), (0.93 * W, 0.92 * H),
           (0.55 * W, 0.98 * H), (0.12 * W, 0.94 * H), (0.03 * W, 0.68 * H), (0.22 * W, 0.4 * H)]
    alpha = polygon_mask(W, H, pts)
    finish(rgb, alpha, (256, 256), 6, seed).save(os.path.join(OUT, "hr_nose.png"))
    print("wrote hr_nose")


# ------------------------------------------------------------------ eyeball
def eyeball(seed=31):
    W = H = 256 * SS
    x, y = grid(W, H, 1.0)
    px = 2.0 / W
    cx, cy, R = -0.12, -0.08, 0.66
    d2 = ((x - cx) ** 2 + (y - cy) ** 2) / R ** 2
    ball = np.clip((1 - d2) / (px * 3 / R), 0, 1)
    z = np.sqrt(np.clip(1 - d2, 0, 1))
    nrm = np.stack([(x - cx) / R, (y - cy) / R, z], -1)
    sclera = np.array([0.94, 0.9, 0.85])
    scale = lambda p: (int((p[0] + 1) / 2 * W), int((p[1] + 1) / 2 * H))
    # the iris, looking off to the side
    icx, icy, ri = cx + 0.24, cy - 0.12, 0.27
    dx, dy = (x - icx) / 0.8, y - icy
    dd = np.sqrt(dx ** 2 + dy ** 2) / ri
    th = np.arctan2(dy, dx)
    fib = noise((H, W), 90, seed + 1, 2)
    icol = mix(np.array([0.5, 0.42, 0.2]), np.array([0.25, 0.42, 0.3]), smooth(0.3, 0.8, dd)) * (0.65 + 0.6 * (0.5 + 0.5 * np.sin(th * 60 + fib * 8)))[..., None]
    icol = mix(icol, np.array([0.05, 0.07, 0.06]), smooth(0.85, 1.0, dd))
    icol = mix(icol, np.array([0.02, 0.02, 0.02]), smooth(0.4, 0.34, dd))
    im = 1 - smooth(0.96, 1.04, dd)
    alb = mix(sclera, icol, im)
    vl = veins(W, H, [(cx - 0.6, cy + 0.3), (cx + 0.1, cy + 0.6), (cx - 0.5, cy - 0.4), (cx + 0.55, cy + 0.3)], seed + 3, 34, scale,
               width=(1, 3), alpha=(0.35, 0.8), toward=(icx, icy), length=0.6)
    vl[..., 3] *= 1 - im
    alb = over(alb, vl)
    # it's been pulled out: bloody round the back
    back = smooth(0.55, 1.0, np.sqrt(d2)) * smooth(-0.3, 0.6, (x - cx) * -0.4 + (y - cy) * 0.9)
    alb = mix(alb, np.array([0.55, 0.08, 0.08]), back * 0.75)
    rgb = light(nrm, alb, wrap=0.4, ambient=0.25, spec=0.9, power=70)
    rgb = rgb * ball[..., None]
    # the optic nerve and a scrap of muscle trailing off
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    r = np.random.default_rng(seed + 5)
    pts = [(cx + 0.35, cy + 0.5)]
    ang = 1.0
    for k in range(14):
        ang += r.normal(0, 0.25) - 0.04
        pts.append((pts[-1][0] + math.cos(ang) * 0.055, pts[-1][1] + math.sin(ang) * 0.055))
    for k in range(len(pts) - 1):
        wdt = int((0.1 - 0.05 * k / len(pts)) * W / 2)
        for j, (c, wk) in enumerate([((0.55, 0.12, 0.12), 1.0), ((0.82, 0.48, 0.45), 0.6), ((0.95, 0.75, 0.7), 0.22)]):
            dr.line([scale(pts[k]), scale(pts[k + 1])], fill=tuple(int(v * 255) for v in c) + (255,), width=max(1, int(wdt * wk)))
    nerve = np.asarray(layer.filter(ImageFilter.GaussianBlur(1.5))).astype(np.float32) / 255.0
    nerve_m = nerve[..., 3] * (1 - ball)
    rgb = mix(rgb, nerve[..., :3], nerve_m)
    alpha = np.clip(ball + nerve_m, 0, 1)
    # blood drips
    blood = (noise((H, W), 8, seed + 7, 3) > 0.7) & (alpha > 0.5)
    rgb = mix(rgb, np.array([0.42, 0.02, 0.03]) + 0.15 * noise((H, W), 60, seed + 8, 1)[..., None], blood * 0.6)
    finish(rgb, alpha, (256, 256), 6, seed).save(os.path.join(OUT, "hr_eyeball.png"))
    print("wrote hr_eyeball")


# ------------------------------------------------------------------ tooth
def tooth(seed=41):
    W, H = 192 * SS, 256 * SS
    x, y = grid(W, H, 0.75)
    px = 1.5 / W
    crown_w = 0.62 * (1 - 0.15 * smooth(-0.5, -0.05, y))
    cusp = 0.09 * np.abs(np.sin((x + 0.05) / 0.62 * math.pi * 1.5)) + 0.12 * (np.abs(x) / 0.62) ** 4
    crown = (np.abs(x) < crown_w) & (y > -0.82 + cusp) & (y < -0.02)
    cr_d = (np.abs(x) / crown_w) ** 2 + np.clip((-0.42 - y) / 0.45, 0, None) ** 2 + np.clip((y + 0.25) / 0.4, 0, None) ** 2 * 0.5
    roots = np.zeros_like(x)
    for sx in (-1, 1):
        k = np.clip((y + 0.1) / 1.0, 0, 1)
        rc = sx * (0.26 + 0.12 * k)
        rw = 0.22 * (1 - k) ** 0.7 + 0.02
        roots = np.maximum(roots, ((np.abs(x - rc) < rw) & (y > -0.15) & (y < 0.9)).astype(np.float32) * np.sqrt(np.clip(1 - ((x - rc) / rw) ** 2, 0, 1)))
    hf = np.where(crown, 0.4 * np.sqrt(np.clip(1 - cr_d, 0, 1)) + 0.05 * np.cos((x / 0.62) * 7) * smooth(-0.45, -0.8, y), 0.0)
    hf = np.maximum(hf, roots * 0.22)
    mask = np.clip(crown.astype(np.float32) + (roots > 0), 0, 1)
    mask = ndimage.gaussian_filter(mask, 1.0)
    hf += 0.008 * noise((H, W), 40, seed + 1, 2)
    n = normals(hf, 1.0, px)
    enamel = np.array([0.95, 0.94, 0.88]) * (0.94 + 0.08 * noise((H, W), 20, seed + 2, 2))[..., None]
    dentin = np.array([0.86, 0.74, 0.55]) * (0.9 + 0.12 * noise((H, W), 30, seed + 3, 2))[..., None]
    alb = mix(enamel, dentin, smooth(-0.1, 0.05, y))
    blood = smooth(0.35, 0.9, y) * (0.5 + 0.5 * noise((H, W), 10, seed + 4, 2))
    alb = mix(alb, np.array([0.5, 0.04, 0.05]), np.clip(blood, 0, 0.9))
    stain = np.exp(-(((x - 0.15) / 0.08) ** 2 + ((y + 0.6) / 0.06) ** 2))
    alb = mix(alb, np.array([0.35, 0.25, 0.15]), stain * 0.8)
    rgb = light(n, alb, wrap=0.4, ambient=0.25, spec=0.6, power=45, spec_map=0.5 + 0.5 * (y < 0) + 0.5 * blood)
    rgb *= ao(hf, 10, 2.0)[..., None]
    finish(rgb, mask, (192, 256), 6, seed).save(os.path.join(OUT, "hr_tooth.png"))
    print("wrote hr_tooth")


# ------------------------------------------------------------------ fish
def fish_layers(W, H, seed, XR=2.0):
    x, y = grid(W, H, XR)
    px = 2 * XR / W
    u = (x + 1.8) / 2.85
    hh = 0.6 * np.clip(u, 0, 1) ** 0.5 * np.clip(1 - u, 0, 1) ** 0.55 / (0.5 ** 0.5 * 0.5 ** 0.55)
    hh = np.maximum(hh, 0.14 * smooth(0.6, 1.0, u)) * (u >= 0)
    hh = np.where(u > 1.0, 0.14, hh)
    yc = 0.04 + 0.04 * np.sin(u * 3.0)
    body = (np.abs(y - yc) < hh) & (u >= 0) & (u <= 1.0)
    rel = np.clip((y - yc) / np.maximum(hh, 1e-3), -1, 1)
    z = np.sqrt(np.clip(1 - rel ** 2, 0, 1))
    # tail
    tx = x - 1.02
    spread = 0.14 + tx * 0.78
    fork = np.clip((tx - 0.45) * 0.7, 0, None)
    tail = (tx > 0) & (tx < 0.8 + 0.12 * np.abs(y - 0.05)) & (np.abs(y - 0.05) < spread) & (np.abs(y - 0.05) > fork)
    fins = tail.astype(np.float32)
    rays = np.zeros_like(x)
    rays = np.maximum(rays, tail * np.abs(np.sin(np.arctan2(y - 0.05, tx + 0.2) * 40)))
    def tri_fin(base0, base1, tip, side):
        a = np.array(base0)
        b = np.array(base1)
        c = np.array(tip)
        pts = [a, b, c]
        m = polygon_mask(W, H, [((p[0] + XR) / (2 * XR) * W, (p[1] + 1) / 2 * H) for p in pts])
        ang = np.arctan2(y - a[1], x - a[0])
        return m, m * np.abs(np.sin(ang * 30))
    for (b0, b1, tp) in [((-0.25, None), (0.45, None), (0.25, -0.95)), ((0.82, None), (0.95, None), (0.97, -0.5))]:
        bx0, bx1 = b0[0], b1[0]
        ub0 = (bx0 + 1.8) / 2.85
        ub1 = (bx1 + 1.8) / 2.85
        def top(ux):
            return 0.04 + 0.04 * math.sin(ux * 3.0) - 0.6 * max(ux, 0) ** 0.5 * max(1 - ux, 0) ** 0.55 / (0.5 ** 0.5 * 0.5 ** 0.55) + 0.03
        m, rr = tri_fin((bx0, top(ub0)), (bx1, top(ub1)), tp, -1)
        fins = np.maximum(fins, m)
        rays = np.maximum(rays, rr)
    for (bx0, bx1, tp) in [((-0.95, 0.12), (-0.8, 0.16), (-0.45, 0.48)), ((0.05, 0.42), (0.25, 0.42), (0.35, 0.72)), ((0.55, 0.36), (0.78, 0.3), (0.88, 0.62))]:
        m, rr = tri_fin(bx0, bx1, tp, 1)
        fins = np.maximum(fins, m)
        rays = np.maximum(rays, rr)
    return x, y, px, body, rel, z, yc, hh, fins, rays, u


def fish(seed=51):
    W, H = 512 * SS, 256 * SS
    x, y, px, body, rel, z, yc, hh, fins, rays, u = fish_layers(W, H, seed)
    bm = ndimage.gaussian_filter(body.astype(np.float32), 0.8)
    # scales: rows of little overlapping arcs, facing the tail
    sc = 0.034
    gu = x / sc
    gv = y / sc + 0.5 * np.floor(gu)
    fu = gu - np.floor(gu)
    fv = gv - np.floor(gv) - 0.5
    arc = np.sqrt(fu ** 2 + (fv * 1.3) ** 2)
    scale_h = np.clip(1 - arc, 0, 1) * 0.005
    head = smooth(-0.82, -0.98, x)
    hf = z * hh * 0.9 + scale_h * (1 - head) * body
    # gill cover
    gill = np.abs(x - (-0.95 + 0.12 * np.cos(rel * 1.4))) < 0.012
    hf -= 0.02 * gill
    hf += 0.01 * noise((H, W), 30, seed + 1, 2)
    n = normals(hf, 1.0, px)
    back = np.array([0.24, 0.31, 0.2])
    side = np.array([0.74, 0.75, 0.7])
    belly = np.array([0.93, 0.92, 0.88])
    alb = mix(back, side, smooth(-0.75, -0.1, rel))
    alb = mix(alb, belly, smooth(0.25, 0.7, rel))
    band = np.exp(-((rel - 0.02) / 0.18) ** 2) * smooth(-1.6, -0.6, x) * (0.75 + 0.25 * noise(x.shape, 12, seed + 9, 2))
    alb = mix(alb, np.array([0.78, 0.4, 0.42]), band * 0.55)
    alb = mix(alb, alb * 0.9, np.clip(1 - arc, 0, 1) ** 2 * 0.25 * (1 - head))
    r = np.random.default_rng(seed + 2)
    spots = np.zeros_like(x)
    for k in range(260):
        sxp = r.uniform(-1.4, 1.85)
        syp = r.uniform(-0.9, 0.6)
        rad = r.uniform(0.012, 0.026)
        spots = np.maximum(spots, smooth(rad, rad * 0.5, np.sqrt((x - sxp) ** 2 + (y - syp) ** 2)))
    upper = smooth(0.4, -0.3, rel) * body + fins * (y < 0.1)
    alb = mix(alb, np.array([0.08, 0.07, 0.06]), spots * np.clip(upper, 0, 1) * 0.85)
    # the lateral line
    ll = np.exp(-((rel + 0.02) / 0.025) ** 2) * (np.sin(x * 140) > 0) * (x > -0.9)
    alb = mix(alb, alb * 0.6, ll * 0.5)
    # mouth and eye
    mouth = (np.abs(y - (0.1 + (x + 1.75) * 0.08)) < 0.012) & (x > -1.78) & (x < -1.45)
    alb = mix(alb, np.array([0.15, 0.1, 0.08]), mouth)
    ed = np.sqrt((x + 1.42) ** 2 + (y + 0.06) ** 2)
    eye = ed < 0.11
    ecol = mix(np.array([0.02, 0.02, 0.02]), np.array([0.75, 0.62, 0.3]), smooth(0.055, 0.07, ed))
    ecol = mix(ecol, np.array([0.3, 0.25, 0.15]), smooth(0.09, 0.11, ed))
    alb = mix(alb, ecol, eye)
    # iridescence in the highlight
    hue = np.stack([0.5 + 0.5 * np.sin(x * 6 + 0), 0.5 + 0.5 * np.sin(x * 6 + 2), 0.5 + 0.5 * np.sin(x * 6 + 4)], -1)
    rgb = light(n, alb, wrap=0.3, ambient=0.3, spec=0.75, power=26, spec_map=0.5 + 0.5 * noise((H, W), 80, seed + 3, 1))
    rgb = rgb + (hue - 0.5) * 0.05 * smooth(0.0, 0.5, z)[..., None] * body[..., None]
    ecl = smooth(0.03, 0.015, np.sqrt((x + 1.45) ** 2 + (y + 0.09) ** 2))
    rgb = rgb + ecl[..., None] * 0.9
    # fins: translucent with rays, pale leading edges
    fcol = np.array([0.55, 0.52, 0.38]) * (0.75 + 0.25 * rays)[..., None]
    fcol = mix(fcol, np.array([0.08, 0.07, 0.06]), spots * 0.8)
    fin_only = fins * (1 - bm)
    rgb = mix(rgb, fcol, fin_only)
    alpha = np.clip(bm + fin_only * 0.92, 0, 1)
    finish(rgb, alpha, (512, 256), 6, seed).save(os.path.join(OUT, "hr_fish.png"))
    print("wrote hr_fish")


# ------------------------------------------------------------------ meat
def meat_albedo(x, y, H, W, seed, fat_edge):
    small = np.random.default_rng(seed).random((H // 2 + 1, W // 24 + 2))
    fibre = ndimage.zoom(small, (H / (H // 2), W / (W // 24)), order=3)[:H, :W]
    fibre = (fibre - fibre.min()) / (np.ptp(fibre) + 1e-6)
    muscle = mix(np.array([0.5, 0.05, 0.07]), np.array([0.78, 0.2, 0.2]), noise((H, W), 8, seed + 1, 3) * 0.7 + fibre * 0.3)
    rid = 1 - np.abs(2 * noise((H, W), 9, seed + 2, 5) - 1)
    marb = ndimage.gaussian_filter(smooth(0.8, 0.97, rid), 1.6) * (0.6 + 0.6 * noise((H, W), 20, seed + 9, 2))
    speck = smooth(0.78, 0.9, noise((H, W), 70, seed + 10, 2)) * 0.35
    alb = mix(muscle, np.array([0.92, 0.74, 0.7]), np.clip(marb + speck, 0, 0.85))
    alb = mix(alb, np.array([0.96, 0.89, 0.72]) * (0.9 + 0.1 * noise((H, W), 40, seed + 3, 2))[..., None], fat_edge)
    return alb, fibre, marb


def meat(seed=61):
    W, H = 320 * SS, 256 * SS
    XR = 1.25
    x, y = grid(W, H, XR)
    px = 2 * XR / W
    th = np.arctan2(y / 0.82, x / 1.12)
    rr = np.sqrt((x / 1.12) ** 2 + (y / 0.82) ** 2)
    wob = 1 + 0.1 * (noise((H, W), 4, seed, 2) - 0.5) * 2
    inside = rr / wob
    mask = np.clip((1 - inside) / (px * 2), 0, 1)
    fat_edge = smooth(0.8, 0.9, inside) * smooth(0.2, -0.5, np.sin(th))
    alb, fibre, marb = meat_albedo(x, y, H, W, seed, fat_edge)
    # a round bone
    bd = np.sqrt(((x + 0.4) / 1.15) ** 2 + ((y - 0.15) / 0.85) ** 2) * (1 + 0.12 * (noise((H, W), 6, seed + 11, 2) - 0.5))
    bone = smooth(0.2, 0.18, bd)
    marrow = smooth(0.13, 0.08, bd)
    alb = mix(alb, np.array([0.93, 0.89, 0.78]) * (0.85 + 0.15 * noise((H, W), 50, seed + 5, 2))[..., None], bone)
    alb = mix(alb, np.array([0.5, 0.14, 0.12]) * (0.6 + 0.6 * noise((H, W), 80, seed + 6, 1))[..., None], marrow)
    hf = 0.18 * np.sqrt(np.clip(1 - inside ** 2, 0, 1)) + 0.03 * fat_edge + 0.01 * fibre + 0.015 * bone - 0.02 * marrow
    hf += 0.006 * noise((H, W), 60, seed + 7, 2)
    n = normals(hf, 1.0, px)
    rgb = light(n, alb, wrap=0.3, ambient=0.25, spec=0.7, power=48, spec_map=0.3 + 1.0 * smooth(0.5, 0.8, noise((H, W), 40, seed + 8, 2)))
    rgb *= ao(hf, 10, 1.5)[..., None]
    finish(rgb, mask, (320, 256), 6, seed).save(os.path.join(OUT, "hr_meat.png"))
    print("wrote hr_meat")


# ------------------------------------------------------------------ HUD strips
def hud_strips(seed=71):
    W, H = 512 * SS, 48 * SS
    x, y = grid(W, H, 512 / 48, 1.0)
    px = 2.0 / H
    fat_edge = smooth(-0.55, -0.8, y)
    alb, fibre, marb = meat_albedo(x, y, H, W, seed, fat_edge)
    hf = 0.12 * np.sqrt(np.clip(1 - y ** 2, 0, 1)) + 0.02 * fat_edge + 0.012 * fibre + 0.008 * noise((H, W), 80, seed + 2, 2)
    n = normals(hf, 1.0, px)
    rgb = light(n, alb, wrap=0.3, ambient=0.3, spec=0.8, power=48, spec_map=0.3 + 1.0 * smooth(0.5, 0.8, noise((H, W), 60, seed + 3, 2)))
    edge = np.clip((1 - np.abs(y) - 0.04 * noise((H, W), 60, seed + 4, 2)) / (px * 2), 0, 1)
    to_img(rgb, edge).resize((512, 48), Image.LANCZOS).save(os.path.join(UI_OUT, "hud_meat.png"))
    print("wrote hud_meat")
    # fish skin for armor
    W, H = 512 * SS, 32 * SS
    x, y = grid(W, H, 512 / 32, 1.0)
    px = 2.0 / H
    sc = 0.32
    gu = x / sc
    gv = y / sc + 0.5 * np.floor(gu)
    fu = gu - np.floor(gu)
    fv = gv - np.floor(gv) - 0.5
    arc = np.sqrt(fu ** 2 + (fv * 1.3) ** 2)
    hf = np.clip(1 - arc, 0, 1) * 0.06 + 0.1 * np.sqrt(np.clip(1 - y ** 2, 0, 1))
    n = normals(hf, 1.0, px)
    alb = mix(np.array([0.3, 0.36, 0.3]), np.array([0.78, 0.8, 0.78]), smooth(-0.8, 0.2, y))
    alb = mix(alb, np.array([0.85, 0.5, 0.55]), np.exp(-((y - 0.1) / 0.25) ** 2) * 0.5)
    alb *= (1 - 0.25 * np.clip(1 - arc, 0, 1) ** 3)[..., None]
    r = np.random.default_rng(seed + 9)
    for k in range(70):
        cx, cy, rad = r.uniform(-11, 11), r.uniform(-0.9, 0.2), r.uniform(0.06, 0.14)
        alb = mix(alb, np.array([0.06, 0.06, 0.05]), smooth(rad, rad * 0.5, np.sqrt((x - cx) ** 2 + (y - cy) ** 2)) * 0.8)
    hue = np.stack([0.5 + 0.5 * np.sin(x * 2 + 0), 0.5 + 0.5 * np.sin(x * 2 + 2), 0.5 + 0.5 * np.sin(x * 2 + 4)], -1)
    rgb = light(n, alb, wrap=0.3, ambient=0.3, spec=0.9, power=30) + (hue - 0.5) * 0.06
    edge = np.clip((1 - np.abs(y)) / (px * 2), 0, 1)
    to_img(rgb, edge).resize((512, 32), Image.LANCZOS).save(os.path.join(UI_OUT, "hud_scales.png"))
    print("wrote hud_scales")


if __name__ == "__main__":
    import sys
    which = sys.argv[1:] or ["all"]
    if "eye" in which or "all" in which:
        eye_atlas("hr_eye", "blue", 0.0, 11)
        eye_atlas("hr_eye_sore", "blue", 1.0, 11)
        eye_atlas("hr_eye_b", "brown", 0.15, 17)
    if "mouth" in which or "all" in which:
        mouth_atlas()
    if "bits" in which or "all" in which:
        nose()
        eyeball()
        tooth()
        fish()
        meat()
    if "hud" in which or "all" in which:
        hud_strips()
