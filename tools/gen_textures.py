"""Generates every world / prop / pickup texture for Gorbino's Quest.

Run:  python3 tools/gen_textures.py
Output: assets/textures/*.png  (64x64 unless noted, quantised to GORBPAL)
"""
import os
import numpy as np
from PIL import Image, ImageDraw
from texlib import *

OUT = os.path.join(ROOT, "assets", "textures")
os.makedirs(OUT, exist_ok=True)
N = 64
YY, XX = np.mgrid[0:N, 0:N].astype(np.float32)
_count = [0]


def save(name, arr, q=True, dither=True):
    to_image(arr, q, dither).save(os.path.join(OUT, name + ".png"))
    _count[0] += 1


def fill(c, h=N, w=N):
    return np.ones((h, w, 3), np.float32) * col(*c)


# ================================================================ builders
def bricks(seed, base, mortar, bw=16, bh=8, var=0.18, noise=0.25, offset=0.5, size=N):
    r = rng(seed)
    img = np.zeros((size, size, 3), np.float32)
    n = value_noise(size, 8, seed + 1, 4)
    rows = size // bh
    for row in range(rows):
        off = int(bw * offset) if row % 2 else 0
        for bx in range(-1, size // bw + 1):
            x0 = bx * bw + off
            c = col(*base) * (1 + (r.random() - 0.5) * 2 * var)
            c = c * (1 + (r.random(3) - 0.5) * 0.12)
            ys, ye = row * bh, row * bh + bh
            for x in range(x0, x0 + bw):
                img[ys:ye, x % size] = c
    img = shade(img, 0.75 + n * noise * 2)
    m = np.zeros((size, size), bool)
    for row in range(rows):
        m[row * bh, :] = True
        off = int(bw * offset) if row % 2 else 0
        for bx in range(-1, size // bw + 1):
            m[row * bh:row * bh + bh, (bx * bw + off) % size] = True
    img[m] = col(*mortar) * (0.8 + 0.4 * n[m][:, None])
    # top-left highlight of each brick
    hl = np.roll(m, 1, 0) & ~m
    img[hl] = np.clip(img[hl] * 1.25, 0, 1)
    return img


def tiles(seed, colors, grout, n=4, var=0.1, noise=0.2, checker=False, size=N, gw=1):
    r = rng(seed)
    ts = size // n
    img = np.zeros((size, size, 3), np.float32)
    nz = value_noise(size, 8, seed + 3, 3)
    for ty in range(n):
        for tx in range(n):
            c = colors[(tx + ty) % len(colors)] if checker else colors[r.integers(len(colors))]
            c = col(*c) * (1 + (r.random() - 0.5) * var * 2)
            img[ty * ts:(ty + 1) * ts, tx * ts:(tx + 1) * ts] = c
    img = shade(img, 0.85 + nz * noise)
    for k in range(n):
        img[k * ts:k * ts + gw, :] = col(*grout)
        img[:, k * ts:k * ts + gw] = col(*grout)
    # bevel highlight
    for k in range(n):
        img[k * ts + gw, :] = np.clip(img[k * ts + gw, :] * 1.2, 0, 1)
    return img


def planks(seed, base, n=4, vertical=True, var=0.15, gap=(20, 12, 8), size=N, nails=True):
    r = rng(seed)
    pw = size // n
    img = np.zeros((size, size, 3), np.float32)
    grain_n = value_noise(size, 4, seed + 7, 3)
    for p in range(n):
        c = col(*base) * (1 + (r.random() - 0.5) * var * 2)
        ph = r.random() * 6
        coord = XX if not vertical else YY
        across = XX if vertical else YY
        grain = 0.85 + 0.15 * np.sin(coord * 0.15 + across * 1.7 + ph + grain_n * 9)
        sl = (slice(None), slice(p * pw, (p + 1) * pw)) if vertical else (slice(p * pw, (p + 1) * pw), slice(None))
        img[sl] = c * grain[sl][..., None]
        if vertical:
            img[:, p * pw] = col(*gap)
            img[:, p * pw + 1] *= 1.15
            if nails:
                for ny in (4, size - 6):
                    img[ny:ny + 2, p * pw + pw // 2:p * pw + pw // 2 + 2] = col(40, 40, 46)
        else:
            img[p * pw, :] = col(*gap)
            img[p * pw + 1, :] *= 1.15
            if nails:
                for nx in (4, size - 6):
                    img[p * pw + pw // 2:p * pw + pw // 2 + 2, nx:nx + 2] = col(40, 40, 46)
    return np.clip(img, 0, 1)


def metal(seed, base, rivets=True, seams=(0,), bevel=True, noise=0.35, size=N, scratch=True):
    n = value_noise(size, 6, seed, 5)
    img = fill(base, size, size)
    img = shade(img, 0.7 + n * noise * 1.6)
    if scratch:
        r = rng(seed + 11)
        for _ in range(14):
            x, y = r.integers(0, size, 2)
            L = r.integers(4, 14)
            dx = r.choice([-1, 1])
            for i in range(L):
                img[(y + i) % size, (x + i * dx) % size] *= 1.25
    for s in seams:
        img[s, :] *= 0.45
        img[:, s] *= 0.45
        img[(s + 1) % size, :] = np.clip(img[(s + 1) % size, :] * 1.3, 0, 1)
        img[:, (s + 1) % size] = np.clip(img[:, (s + 1) % size] * 1.3, 0, 1)
    if rivets:
        for (rx, ry) in [(4, 4), (size - 6, 4), (4, size - 6), (size - 6, size - 6)]:
            img[ry:ry + 2, rx:rx + 2] = np.clip(col(*base) * 1.6, 0, 1)
            img[ry + 2, rx:rx + 2] *= 0.3
    return img


def rock(seed, stops, cells=10, size=N, cracks=True):
    d1, d2, ids = worley(size, cells, seed)
    n = value_noise(size, 8, seed + 2, 5)
    edge = np.clip((d2 - d1) / 6.0, 0, 1)
    r = rng(seed)
    cv = r.random(cells)[ids]
    t = 0.25 + 0.45 * n + 0.2 * cv
    img = gradmap(t, stops)
    if cracks:
        img = shade(img, 0.45 + 0.55 * edge)
    return img


def marble(seed, stops, freq=0.14, turb=7.0, size=N):
    n = value_noise(size, 4, seed, 5)
    t = 0.5 + 0.5 * np.sin((XX + YY * 0.6) * freq * (64 / size) + n * turb)
    t = t ** 2.5
    n2 = value_noise(size, 16, seed + 5, 3)
    return gradmap(np.clip(t * 0.8 + n2 * 0.25, 0, 1), stops)


def stripes_diag(c1, c2, w=8, size=N):
    m = (((XX + YY) // w) % 2).astype(np.float32)
    return lerp(np.ones((size, size, 3)) * col(*c1), np.ones((size, size, 3)) * col(*c2), m)


def text_panel(text, fnt_name, fsize, bg, fg, outline_c=None, size=(N, N), spacing=0, shadow=None, base=None):
    w, h = size
    img = base if base is not None else fill(bg, h, w)
    m = text_layer((w, h), text, font(fnt_name, fsize), spacing=spacing)
    m = (m > 0.5).astype(np.float32)
    if shadow is not None:
        sm = np.roll(np.roll(m, 1, 0), 1, 1)
        img = paste_mask(img, sm, shadow)
    if outline_c is not None:
        img = paste_mask(img, outline(m, 1), outline_c)
    img = paste_mask(img, m, fg)
    return img


def grime(img, seed, amt=0.35, size=N):
    n = value_noise(size, 4, seed, 4)
    drip = value_noise(size, 16, seed + 9, 2)
    streak = np.clip(np.sin(XX * 0.9 + drip * 6) * 0.5 + 0.5, 0, 1) * (YY / size)
    return shade(img, 1 - amt * (n * 0.6 + streak * 0.4))


def gorb_face_mask(cx, cy, r, size=N):
    """Mask of a Gorbino emblem: tall octopus mantle, slit eyes, tentacles."""
    body = ((XX - cx) ** 2 / (r * 0.8) ** 2 + (YY - (cy - r * 0.25)) ** 2 / (r * 0.95) ** 2) < 1
    for k in range(5):
        tx = cx + (k - 2) * r * 0.36
        wav = np.sin((YY - cy) * 0.6 + k) * r * 0.08
        tent = (np.abs(XX - tx - wav) < r * 0.11) & (YY > cy + r * 0.3) & (YY < cy + r * 1.05)
        body = body | tent
    eyes = np.zeros_like(body)
    for sx in (-1, 1):
        ex, ey = cx + sx * r * 0.32, cy - r * 0.18
        eyes = eyes | ((np.abs(YY - ey) < max(r * 0.07, 0.6)) & (np.abs(XX - ex) < r * 0.22))
    mouth = (np.abs(YY - (cy + r * 0.2)) < max(r * 0.06, 0.6)) & (np.abs(XX - cx) < r * 0.3)
    return body.astype(np.float32), (mouth | eyes).astype(np.float32), eyes.astype(np.float32)


# ================================================================ common
def common():
    # Doors
    base = metal(100, (96, 104, 92), rivets=False, seams=())
    for y in range(0, N, 16):
        base[y:y + 2, :] *= 0.5
        base[y + 2, :] = np.clip(base[y + 2, :] * 1.3, 0, 1)
    base[:, 0:3] *= 0.6
    base[:, N - 3:] *= 0.6
    body, holes, _eyes = gorb_face_mask(32, 30, 12)
    emb = paste_mask(base.copy(), body, (170, 176, 60))
    emb = paste_mask(emb, holes, (30, 30, 20))
    emb = paste_mask(emb, outline(body), (30, 30, 20))
    save("door_metal", emb)
    for name, c in [("door_red", (230, 30, 40)), ("door_blue", (40, 90, 255)), ("door_yellow", (250, 220, 40))]:
        d = base.copy()
        d[:, 26:38] = col(*c) * (0.75 + 0.25 * value_noise(N, 8, 5, 3))[:, 26:38, None]
        d[:, 25] = col(20, 20, 20)
        d[:, 38] = col(20, 20, 20)
        # key slot
        d[28:38, 29:35] = col(20, 20, 24)
        d[30:36, 31:33] = col(*c)
        save(name, d)
    # switches
    for name, lamp in [("switch_off", (200, 30, 30)), ("switch_on", (60, 255, 60))]:
        s = metal(120, (70, 74, 84), seams=())
        s[18:46, 22:42] = col(30, 32, 36)
        bevel_rect(s, 22, 18, 42, 46, 0.2, 0.4)
        lever_y = 24 if name == "switch_off" else 36
        s[lever_y:lever_y + 6, 26:38] = col(210, 200, 60)
        s[lever_y:lever_y + 1, 26:38] = col(255, 250, 140)
        s[8:13, 29:35] = col(*lamp)
        s[9:10, 30:32] = np.clip(col(*lamp) + 0.4, 0, 1)
        save(name, s)
    # exit panel
    e = metal(130, (60, 60, 70), seams=())
    e = text_panel("EXIT", "Bungee-Regular.ttf", 17, None, (255, 40, 40), outline_c=(40, 0, 0), base=e)
    e[46:58, 22:42] = col(30, 30, 36)
    e[48:56, 26:38] = col(240, 230, 60)
    save("exit_panel", e)
    # tech panels
    t = metal(140, (64, 70, 80), seams=(0, 32))
    r = rng(141)
    for i in range(30):
        x, y = r.integers(4, 58), r.integers(4, 58)
        c = [(255, 60, 60), (60, 255, 80), (255, 220, 40), (60, 200, 255)][r.integers(4)]
        t[y:y + 2, x:x + 3] = col(*c)
    t[10:24, 8:28] = col(10, 40, 20)
    for yy in range(11, 23, 3):
        t[yy, 10:10 + r.integers(6, 16)] = col(80, 255, 120)
    save("tech_panel", t)
    t2 = metal(150, (40, 46, 60), seams=(0,))
    for y in range(6, 60, 8):
        t2[y:y + 4, 6:58] = col(20, 22, 30)
        for x in range(8, 56, 6):
            t2[y + 1:y + 3, x:x + 3] = col(*[(255, 40, 200), (40, 255, 200), (255, 255, 255)][(x // 6 + y // 8) % 3]) * (0.5 + 0.5 * r.random())
    save("tech_panel2", t2)
    # diamond plate floor
    dp = metal(160, (110, 112, 118), rivets=False, seams=())
    bump = ((np.abs(((XX + YY) % 8) - 4) < 1.2) & (np.abs(((XX - YY) % 16) - 8) < 4)).astype(np.float32)
    dp = shade(dp, 1 + bump * 0.35)
    save("metal_floor", dp)
    # crate
    c = planks(170, (150, 110, 60), n=4, vertical=False)
    c[0:4, :] = col(80, 60, 30); c[-4:, :] = col(80, 60, 30)
    c[:, 0:4] = col(80, 60, 30); c[:, -4:] = col(80, 60, 30)
    for i in range(N):
        c[i, max(0, i - 2):i + 2] = col(110, 80, 40)
    c = text_panel("FRAGILE", "Anton-Regular.ttf", 13, None, (40, 20, 10), base=c)
    save("crate", c)
    # support beam
    sb = metal(180, (90, 70, 50), seams=(), rivets=False)
    sb[:, 0:8] *= 0.6; sb[:, 56:] *= 0.6
    for y in range(4, N, 12):
        sb[y:y + 2, 12:14] = col(200, 180, 120); sb[y:y + 2, 50:52] = col(200, 180, 120)
    save("support", sb)
    # liquids
    def liquid(name, stops, seed):
        n1 = value_noise(N, 4, seed, 4)
        n2 = value_noise(N, 8, seed + 1, 3)
        t = 0.5 + 0.5 * np.sin(n1 * 12 + n2 * 4)
        save(name, gradmap(t, stops))
    liquid("liq_sludge", [(0, (20, 60, 0)), (0.5, (120, 220, 20)), (0.9, (220, 255, 120)), (1, (255, 255, 200))], 190)
    liquid("liq_goo", [(0, (90, 0, 40)), (0.5, (230, 40, 140)), (1, (255, 180, 230))], 191)
    liquid("liq_water", [(0, (0, 30, 40)), (0.6, (20, 140, 150)), (1, (160, 255, 240))], 192)
    liquid("liq_magma", [(0, (80, 10, 0)), (0.5, (255, 100, 10)), (0.85, (255, 230, 60)), (1, (255, 255, 200))], 193)
    liquid("liq_ooze", [(0, (20, 0, 40)), (0.5, (120, 40, 220)), (1, (230, 160, 255))], 194)
    # teleporter pad
    tp = fill((20, 20, 30))
    rr = np.hypot(XX - 31.5, YY - 31.5)
    tp = paste_mask(tp, ((rr % 8) < 3).astype(np.float32) * (rr < 30), (120, 255, 230))
    tp = paste_mask(tp, (rr < 5).astype(np.float32), (255, 255, 255))
    save("teleport_pad", tp)
    # checkpoint totem
    ck = fill((30, 30, 40))
    ck = text_panel("SAVE", "Silkscreen-Bold.ttf", 16, None, (120, 255, 120), base=ck)
    save("checkpoint", ck)
    # skin textures (greyscale, tinted at runtime)
    n = value_noise(N, 8, 300, 4)
    sp = (white(N, 301) > 0.93).astype(np.float32)
    g = 0.72 + n * 0.3 - sp * 0.12
    save("gorbino_skin", np.stack([g, g, g], -1), q=False)
    n = value_noise(N, 6, 310, 4)
    d1, d2, _ = worley(N, 14, 311)
    spots = (d1 < 4).astype(np.float32)
    sk = gradmap(0.4 + n * 0.4, [(0, (150, 110, 170)), (1, (230, 190, 240))])
    sk = paste_mask(sk, spots * 0.8, (110, 60, 140))
    save("snirby_skin", sk)
    save("snirby_belly", gradmap(0.5 + value_noise(N, 8, 312) * 0.5, [(0, (220, 190, 180)), (1, (255, 235, 225))]))
    # eye / misc colour swatches
    save("white", fill((240, 240, 230)), q=False)
    save("black", fill((14, 12, 16)), q=False)
    # barrel
    b = metal(320, (40, 140, 40), rivets=False, seams=())
    for y in (6, 7, 56, 57):
        b[y, :] = col(20, 60, 20)
    b[20:44, 4:60] = col(240, 230, 210)
    b = text_panel("TOXIC", "Anton-Regular.ttf", 13, None, (200, 20, 20), base=b)
    b[20:44, :] = np.where(np.abs(np.arange(N) - 32)[None, :, None] < 28, b[20:44, :], col(40, 140, 40))
    b = grime(b, 321, 0.35)
    save("barrel", b)
    save("barrel_top", shade(fill((50, 150, 50)), 0.7 + 0.5 * value_noise(N, 8, 322)))
    # statue stone
    save("stone", rock(330, [(0, (60, 60, 64)), (0.6, (140, 136, 130)), (1, (200, 196, 190))], cells=20, cracks=False))
    # lamp glow
    lg = fill((255, 250, 200))
    lg = shade(lg, 0.85 + 0.15 * np.cos(np.hypot(XX - 32, YY - 32) * 0.2))
    save("lamp", lg, q=False)


# ================================================================ pickups / weapons
def pickups():
    # medkit: white box, green plus, gorbino stamp
    m = fill((230, 230, 222))
    m = shade(m, 0.85 + 0.2 * value_noise(N, 8, 400))
    m[22:42, 28:36] = col(40, 200, 60)
    m[28:36, 22:42] = col(40, 200, 60)
    m[0:3, :] *= 0.7; m[-3:, :] *= 0.7; m[:, 0:3] *= 0.7; m[:, -3:] *= 0.7
    save("pk_medkit", m)
    # stim / gorb juice can
    j = fill((240, 120, 30))
    j[:, :] = shade(j, 0.75 + 0.35 * np.cos((XX - 20) * 0.09))
    j = text_panel("VITAL", "Anton-Regular.ttf", 14, None, (255, 255, 230), outline_c=(90, 20, 0), base=j)
    save("pk_juice", j)
    # ammo boxes
    for name, base, label, fg in [
        ("pk_bullets", (110, 120, 50), "9MM", (250, 240, 200)),
        ("pk_shells", (170, 40, 30), "SHELLS", (255, 220, 60)),
        ("pk_rockets", (60, 70, 60), "ROCKET", (255, 140, 20)),
        ("pk_cells", (30, 60, 110), "CELL", (100, 255, 255)),
    ]:
        a = metal(410 + len(name), base, seams=(), rivets=True, scratch=False)
        a = text_panel(label, "Silkscreen-Bold.ttf", 8 if "\n" in label or len(label) > 4 else 16, None, fg, base=a, spacing=1)
        a[0:2, :] *= 0.5; a[-2:, :] *= 0.5; a[:, 0:2] *= 0.5; a[:, -2:] *= 0.5
        save(name, a)
    # keycards
    for name, c in [("pk_key_red", (240, 30, 40)), ("pk_key_blue", (40, 100, 255)), ("pk_key_yellow", (255, 220, 30))]:
        k = fill(c)
        k = shade(k, 0.8 + 0.3 * value_noise(N, 8, 420))
        k[6:20, 6:58] = col(250, 250, 240)
        body, holes, _eyes = gorb_face_mask(32, 42, 14)
        k = paste_mask(k, body, (255, 255, 255))
        k = paste_mask(k, holes, (20, 20, 20))
        k[10:14, 10:54] = col(20, 20, 20)
        save(name, k)
    # armor vests
    for name, c in [("pk_armor_green", (40, 170, 60)), ("pk_armor_blue", (40, 70, 220))]:
        a = fill(c)
        n = value_noise(N, 8, 430)
        a = shade(a, 0.7 + 0.5 * n)
        for y in range(0, N, 8):
            a[y, :] *= 0.6
        for x in range(0, N, 8):
            a[:, x] *= 0.75
        save(name, a)
    # mega orb (swirly)
    rr = np.hypot(XX - 32, YY - 32)
    ang = np.arctan2(YY - 32, XX - 32)
    t = 0.5 + 0.5 * np.sin(ang * 3 + rr * 0.35)
    save("pk_orb", gradmap(t, [(0, (90, 0, 140)), (0.5, (255, 60, 220)), (1, (255, 240, 255))]))
    save("pk_orb_blue", gradmap(t, [(0, (0, 30, 120)), (0.5, (40, 180, 255)), (1, (230, 255, 255))]))
    # weapon materials
    save("gun_metal", metal(440, (58, 62, 72), rivets=False, seams=(), noise=0.25))
    save("gun_dark", metal(441, (30, 30, 36), rivets=False, seams=(), noise=0.25))
    save("gun_wood", planks(442, (120, 60, 30), n=2, vertical=False, nails=False))
    save("gun_brass", shade(fill((210, 170, 60)), 0.75 + 0.4 * value_noise(N, 8, 443)))
    save("gun_red", metal(444, (160, 30, 30), rivets=False, seams=(), noise=0.25))
    save("gun_green", metal(445, (60, 120, 40), rivets=False, seams=(), noise=0.25))
    save("gun_plasma", gradmap(value_noise(N, 4, 446), [(0, (0, 60, 80)), (0.6, (60, 240, 255)), (1, (240, 255, 255))]))
    save("gun_purple", metal(447, (110, 50, 150), rivets=False, seams=(), noise=0.3))
    # hazmat glove (player's hands)
    g = fill((230, 200, 40))
    g = shade(g, 0.75 + 0.35 * value_noise(N, 8, 450))
    for y in range(4, N, 10):
        g[y, :] *= 0.85
    save("glove", g)


# ================================================================ level 1: village
def village():
    g = value_noise(N, 8, 500, 5)
    blades = white(N, 501)
    t = np.clip(g * 0.7 + blades * 0.35, 0, 1)
    save("v_grass", gradmap(t, [(0, (30, 70, 0)), (0.5, (120, 200, 20)), (1, (220, 255, 80))]))
    d = value_noise(N, 8, 502, 5)
    pebbles = (white(N, 503) > 0.95).astype(np.float32)
    dirt = gradmap(d, [(0, (70, 40, 20)), (1, (170, 120, 70))])
    save("v_dirt", paste_mask(dirt, pebbles, (200, 180, 150)))
    cb = rock(504, [(0, (60, 50, 70)), (0.5, (130, 110, 140)), (1, (200, 180, 200))], cells=14)
    save("v_cobble", cb)
    pl = fill((240, 150, 130))
    pl = shade(pl, 0.8 + 0.3 * value_noise(N, 8, 505, 5))
    cr = value_noise(N, 16, 506, 2)
    pl = paste_mask(pl, (np.abs(cr - 0.5) < 0.012).astype(np.float32), (120, 60, 50))
    save("v_plaster", grime(pl, 507, 0.25))
    tb = pl.copy()
    beam = (110, 50, 70)
    tb[0:6, :] = col(*beam); tb[-6:, :] = col(*beam)
    tb[:, 0:5] = col(*beam); tb[:, 30:35] = col(*beam)
    for i in range(N):
        x = int(i * 30 / N)
        tb[i, 34 + x - 2:34 + x + 2] = col(*beam)
    tb = shade(tb, 0.85 + 0.2 * value_noise(N, 8, 508))
    save("v_timber", tb)
    save("v_brick", bricks(509, (150, 70, 140), (60, 40, 60)))
    pk = planks(510, (40, 170, 170), n=4)
    peel = value_noise(N, 8, 511, 4) > 0.62
    pk[peel] = col(120, 80, 50) * (0.8 + 0.4 * value_noise(N, 8, 512)[peel][:, None])
    save("v_planks", pk)
    sh = np.zeros((N, N, 3), np.float32)
    for row in range(8):
        off = 4 if row % 2 else 0
        for x in range(N):
            k = ((x + off) % 8)
            c = col(200, 50, 40) * (0.7 + 0.04 * k)
            sh[row * 8:row * 8 + 8, x] = c
        sh[row * 8 + 7, :] *= 0.5
    for x in range(0, N, 8):
        for row in range(8):
            off = 4 if row % 2 else 0
            sh[row * 8:row * 8 + 8, (x + off) % N] *= 0.6
    save("v_shingle", shade(sh, 0.8 + 0.3 * value_noise(N, 8, 513)))
    h = value_noise(N, 8, 514, 5)
    lv = (white(N, 515) > 0.7).astype(np.float32)
    hedge = gradmap(h * 0.8 + lv * 0.25, [(0, (10, 40, 10)), (0.6, (40, 120, 40)), (1, (140, 220, 80))])
    fl = (white(N, 516) > 0.985).astype(np.float32)
    save("v_hedge", paste_mask(hedge, fl, (255, 120, 220)))
    save("v_stonewall", rock(517, [(0, (50, 50, 60)), (0.6, (120, 120, 120)), (1, (180, 190, 170))], cells=12))
    save("v_woodfloor", planks(518, (160, 100, 60), n=4, vertical=False))
    cw = planks(519, (90, 60, 40), n=2, vertical=True, nails=False)
    save("v_ceiling", cw)
    fb = gradmap(value_noise(N, 8, 520, 4), [(0, (60, 40, 20)), (1, (110, 80, 40))])
    r = rng(521)
    for _ in range(40):
        x, y = r.integers(0, N - 3, 2)
        c = [(255, 60, 160), (255, 230, 40), (140, 80, 255), (255, 255, 255)][r.integers(4)]
        fb[y:y + 3, x + 1] = col(*c); fb[y + 1, x:x + 3] = col(*c)
        fb[y + 1, x + 1] = col(255, 220, 0)
    save("v_flowers", fb)
    # signage
    s = fill((250, 230, 60))
    s = text_panel("GORB\nVILLE", "Anton-Regular.ttf", 17, None, (140, 20, 120), base=s, spacing=-3)
    s[0:3, :] = col(110, 50, 70); s[-3:, :] = col(110, 50, 70); s[:, 0:3] = col(110, 50, 70); s[:, -3:] = col(110, 50, 70)
    save("v_sign", s)
    p = fill((30, 160, 220))
    body, holes, _eyes = gorb_face_mask(32, 28, 16)
    p = paste_mask(p, body, (120, 230, 40))
    p = paste_mask(p, holes, (20, 20, 20))
    p = paste_mask(p, text_layer((N, N), "VOTE", font("Bungee-Regular.ttf", 12), anchor_xy=(10, 46)), (255, 255, 255))
    save("v_poster", grime(p, 522, 0.3))
    w = pl.copy()
    w[14:50, 16:48] = col(30, 40, 80)
    w[14:50, 31:33] = col(110, 50, 70)
    w[31:33, 16:48] = col(110, 50, 70)
    w[18:30, 20:28] = col(255, 230, 120)  # lit pane
    w[14:50, 8:16] = col(40, 170, 170); w[14:50, 48:56] = col(40, 170, 170)
    for y in range(14, 50, 4):
        w[y, 8:16] *= 0.6; w[y, 48:56] *= 0.6
    save("v_window", w)


# ================================================================ level 2: industrial
def industrial():
    rust = metal(600, (120, 70, 50), seams=(0, 32))
    rn = value_noise(N, 8, 601, 5)
    rust = paste_mask(rust, (rn > 0.6).astype(np.float32) * 0.85, (170, 80, 20))
    save("i_rust", grime(rust, 602, 0.3))
    cor = fill((90, 120, 120))
    cor = shade(cor, 0.75 + 0.25 * np.sin(XX * np.pi / 4) + 0.2 * value_noise(N, 8, 603))
    save("i_corrugated", grime(cor, 604, 0.4))
    hz = stripes_diag((250, 200, 20), (20, 20, 20), w=8)
    save("i_hazard", grime(hz, 605, 0.35))
    gr = fill((40, 40, 40))
    holes = ((XX % 8) > 1) & ((YY % 8) > 1)
    gr[~holes] = col(130, 130, 120)
    gr[holes] = col(15, 12, 10)
    save("i_grate", shade(gr, 0.85 + 0.3 * value_noise(N, 8, 606)))
    save("i_concrete", grime(gradmap(value_noise(N, 8, 607, 5) * 0.7 + white(N, 608) * 0.3, [(0, (90, 90, 86)), (1, (170, 168, 160))]), 609, 0.3))
    cf = gradmap(value_noise(N, 8, 610, 5) * 0.7 + white(N, 611) * 0.3, [(0, (80, 78, 70)), (1, (150, 146, 136))])
    st = value_noise(N, 4, 612, 3) > 0.62
    cf[st] *= 0.55
    cf[0, :] *= 0.6; cf[:, 0] *= 0.6
    save("i_floor", cf)
    pp = fill((40, 40, 46))
    for i, x in enumerate(range(1, N - 9, 12)):
        c = [(170, 90, 40), (60, 140, 150), (180, 170, 60)][i % 3]
        prof = np.cos((np.arange(10) - 4.5) / 5.5 * 1.4)
        pp[:, x:x + 10] = col(*c) * prof[None, :, None]
    pp[20:24, :] = col(80, 80, 90); pp[50:54, :] = col(80, 80, 90)
    save("i_pipes", grime(pp, 613, 0.3))
    v = metal(614, (100, 104, 110), seams=())
    for y in range(10, 54, 6):
        v[y:y + 3, 10:54] = col(10, 10, 12)
        v[y + 3, 10:54] *= 1.3
    save("i_vent", v)
    mc = metal(615, (60, 120, 110), seams=(0,))
    for (cx, cy) in [(18, 20), (46, 20)]:
        rr = np.hypot(XX - cx, YY - cy)
        mc = paste_mask(mc, (rr < 9).astype(np.float32), (230, 230, 210))
        mc = paste_mask(mc, ((rr < 10) & (rr >= 9)).astype(np.float32), (20, 20, 20))
        ang = 0.7 if cx < 30 else 2.2
        for k in range(8):
            px, py = int(cx + np.cos(ang) * k), int(cy - np.sin(ang) * k)
            mc[py, px] = col(220, 20, 20)
    mc[40:56, 8:56] = col(20, 20, 24)
    for x in range(10, 54, 6):
        mc[44:52, x:x + 4] = col(*[(255, 60, 40), (60, 255, 60), (255, 220, 40)][(x // 6) % 3])
    save("i_machine", mc)
    cv = fill((30, 30, 30))
    for y in range(0, N, 8):
        cv[y:y + 6, :] = col(60, 60, 64)
        cv[y + 1, :] = col(90, 90, 96)
    cv[:, 0:4] = col(200, 170, 30); cv[:, -4:] = col(200, 170, 30)
    save("i_conveyor", cv)
    sg = metal(616, (20, 90, 100), seams=())
    sg = text_panel("SNIRBY\nINDUSTRIAL", "Anton-Regular.ttf", 13, None, (255, 230, 60), outline_c=(10, 30, 30), base=sg, spacing=-2)
    save("i_sign", sg)
    wn = fill((250, 210, 20))
    wn = text_panel("NO\nENTRY", "Silkscreen-Bold.ttf", 8, None, (20, 20, 20), base=wn, spacing=4)
    wn[0:4, :] = col(20, 20, 20); wn[-4:, :] = col(20, 20, 20)
    save("i_warning", grime(wn, 617, 0.25))
    tp = metal(618, (30, 120, 120), seams=(0, 32))
    save("i_teal", grime(tp, 619, 0.25))
    ic = metal(620, (70, 70, 74), seams=(0,), rivets=False)
    ic[26:38, 4:60] = col(240, 250, 230)
    ic[25, 4:60] = col(30, 30, 30); ic[38, 4:60] = col(30, 30, 30)
    save("i_ceiling", ic)
    save("i_light", shade(fill((250, 250, 220)), 0.9 + 0.1 * value_noise(N, 8, 621)), q=False)


# ================================================================ level 3: mines
def mines():
    save("m_rock", rock(700, [(0, (40, 20, 30)), (0.5, (110, 70, 80)), (1, (180, 140, 130))], cells=9))
    save("m_rock2", rock(701, [(0, (20, 14, 24)), (0.5, (70, 50, 70)), (1, (130, 100, 120))], cells=7))
    save("m_dirt", gradmap(value_noise(N, 8, 702, 5) * 0.8 + white(N, 703) * 0.2, [(0, (40, 25, 20)), (1, (120, 80, 60))]))
    bm = planks(704, (120, 80, 40), n=1, vertical=True, nails=False)
    bm = shade(bm, 0.8 + 0.4 * np.cos((XX - 32) / 40))
    for y in (8, 56):
        bm[y:y + 3, :] = col(60, 60, 66); bm[y, :] *= 1.4
    save("m_beam", bm)
    cr = rock(705, [(0, (30, 16, 30)), (0.5, (80, 50, 80)), (1, (140, 110, 130))], cells=9)
    d1, d2, ids = worley(N, 6, 706)
    crystal = (d1 < 7).astype(np.float32)
    shine = np.clip(1 - d1 / 7, 0, 1)
    cr = paste_mask(cr, crystal, (230, 40, 220))
    cr = paste_mask(cr, crystal * (shine > 0.6), (255, 200, 255))
    save("m_crystal", cr)
    ore = rock(707, [(0, (40, 30, 30)), (0.5, (100, 80, 70)), (1, (170, 150, 130))], cells=10)
    spk = (value_noise(N, 16, 708, 2) > 0.66).astype(np.float32)
    ore = paste_mask(ore, spk, (140, 255, 40))
    save("m_ore", ore)
    rl = gradmap(value_noise(N, 8, 709, 5), [(0, (40, 30, 26)), (1, (100, 80, 60))])
    for y in range(4, N, 16):
        rl[y:y + 6, :] = col(90, 60, 30)
        rl[y, :] *= 1.3
    rl[:, 12:16] = col(130, 130, 140); rl[:, 48:52] = col(130, 130, 140)
    rl[:, 12] = col(200, 200, 210); rl[:, 48] = col(200, 200, 210)
    save("m_rail", rl)
    save("m_planks", planks(710, (110, 70, 40), n=4, vertical=False))
    lt = rock(711, [(0, (40, 20, 30)), (0.5, (110, 70, 80)), (1, (180, 140, 130))], cells=9)
    rr = np.hypot(XX - 32, YY - 30)
    glow = np.clip(1 - rr / 30, 0, 1) ** 2
    lt = np.clip(lt + glow[..., None] * col(255, 160, 40), 0, 1)
    lt[22:40, 26:38] = col(255, 230, 120)
    lt[20:22, 24:40] = col(40, 30, 20); lt[40:42, 24:40] = col(40, 30, 20)
    save("m_lantern", lt)
    sg = planks(712, (130, 90, 50), n=4, vertical=False)
    sg = text_panel("DIG\nDEEPER", "Anton-Regular.ttf", 15, None, (250, 240, 200), outline_c=(40, 20, 10), base=sg, spacing=-4)
    save("m_sign", sg)


# ================================================================ level 4: consumer HQ
def hq():
    cp = fill((20, 110, 110))
    pat = (((XX // 8) + (YY // 8)) % 2).astype(np.float32)
    diamonds = (np.abs((XX % 16) - 8) + np.abs((YY % 16) - 8) < 5).astype(np.float32)
    cp = paste_mask(cp, pat * 0.25, (120, 20, 60))
    cp = paste_mask(cp, diamonds, (220, 170, 40))
    cp = shade(cp, 0.8 + 0.3 * white(N, 800))
    save("h_carpet", cp)
    c2 = fill((140, 20, 40))
    rings = (np.abs(np.hypot((XX % 32) - 16, (YY % 32) - 16) - 10) < 2).astype(np.float32)
    c2 = paste_mask(c2, rings, (240, 190, 60))
    c2 = shade(c2, 0.8 + 0.3 * white(N, 801))
    save("h_carpet2", c2)
    seams = ((XX < 1) | (YY < 1) | (np.abs(XX - 32) < 1) | (np.abs(YY - 32) < 1))[..., None]
    save("h_marble", np.where(seams, col(110, 60, 80),
                              marble(802, [(0, (240, 190, 210)), (0.7, (200, 140, 170)), (1, (120, 50, 90))])))
    save("h_marble_wall", marble(803, [(0, (20, 80, 60)), (0.6, (60, 160, 120)), (1, (220, 255, 230))], freq=0.2))
    pn = planks(804, (110, 50, 30), n=4, vertical=True, nails=False)
    pn[0:4, :] = col(70, 30, 20); pn[30:33, :] = col(70, 30, 20); pn[-3:, :] = col(70, 30, 20)
    save("h_panel", pn)
    wp = fill((180, 140, 170))
    for (cx, cy) in [(16, 16), (48, 48)]:
        body, holes, _eyes = gorb_face_mask(cx, cy, 8)
        wp = paste_mask(wp, body * 0.6, (150, 100, 140))
    wp = shade(wp, 0.85 + 0.2 * value_noise(N, 8, 805))
    for x in range(0, N, 16):
        wp[:, x] *= 0.85
    save("h_wallpaper", wp)
    ce = fill((210, 205, 190))
    ce = shade(ce, 0.85 + 0.2 * white(N, 806))
    ce[0, :] = col(120, 120, 110); ce[32, :] = col(120, 120, 110)
    ce[:, 0] = col(120, 120, 110); ce[:, 32] = col(120, 120, 110)
    save("h_ceiling", ce)
    cl = ce.copy()
    cl[4:28, 4:60] = col(245, 255, 240)
    cl[36:60, 4:60] = col(245, 255, 240)
    save("h_ceilinglight", cl, q=False)
    for name, txt, bg, fg, fs in [("h_poster1", "CONSUME", (255, 30, 150), (255, 255, 0), 11),
                                  ("h_poster2", "OBEY\nTHE\nBOARD", (20, 20, 20), (0, 255, 120), 14),
                                  ("h_poster3", "SUBMIT", (250, 240, 220), (200, 0, 30), 15),
                                  ("h_poster4", "WORK\nHARDER", (40, 60, 220), (255, 255, 255), 13)]:
        p = text_panel(txt, "Anton-Regular.ttf", fs, bg, fg, spacing=-3)
        p[0:2, :] = col(30, 20, 20); p[-2:, :] = col(30, 20, 20); p[:, 0:2] = col(30, 20, 20); p[:, -2:] = col(30, 20, 20)
        save(name, p)
    el = metal(807, (160, 160, 170), seams=(), rivets=False)
    el[:, 31:33] = col(30, 30, 30)
    el[:, 0:3] = col(80, 70, 40); el[:, -3:] = col(80, 70, 40)
    save("h_elevator", el)
    wn = fill((10, 10, 40))
    r = rng(808)
    for _ in range(28):
        x, y = r.integers(0, 60), r.integers(20, 62)
        h = r.integers(6, 30)
        wn[64 - h:, x:x + 4] = col(30, 30, 50)
        for wy in range(64 - h + 2, 63, 3):
            if r.random() < 0.5:
                wn[wy, x + 1] = col(255, 220, 100)
    wn[:, 0:3] = col(60, 60, 70); wn[:, -3:] = col(60, 60, 70)
    wn[0:3, :] = col(60, 60, 70); wn[-3:, :] = col(60, 60, 70)
    wn[:, 31:33] = col(60, 60, 70)
    save("h_window", wn)
    cm = fill((80, 60, 40))
    for (x0, y0) in [(4, 8), (34, 8), (4, 38), (34, 38)]:
        cm[y0:y0 + 20, x0:x0 + 26] = col(210, 200, 170)
        cm[y0 + 2:y0 + 16, x0 + 2:x0 + 24] = col(10, 30, 20)
        for ly in range(y0 + 4, y0 + 15, 3):
            cm[ly, x0 + 4:x0 + 4 + r.integers(6, 18)] = col(60, 255, 120)
    save("h_computer", cm)
    lg = fill((240, 240, 235))
    rr = np.hypot(XX - 32, YY - 24)
    lg = paste_mask(lg, ((rr < 16) & (rr > 10)).astype(np.float32), (230, 20, 60))
    lg = paste_mask(lg, (rr < 6).astype(np.float32), (230, 20, 60))
    lg = paste_mask(lg, text_layer((N, N), "CONSUMER", font("Silkscreen-Bold.ttf", 8), anchor_xy=(1, 46)), (30, 30, 30))
    save("h_logo", lg)


# ================================================================ level 5: facility
def facility():
    save("f_tile", grime(tiles(900, [(230, 235, 230), (215, 225, 220)], (140, 150, 140), n=8), 901, 0.35))
    save("f_tile_green", grime(tiles(902, [(150, 230, 190), (130, 210, 170)], (60, 100, 80), n=8), 903, 0.3))
    hx = fill((100, 110, 105))
    q = ((XX % 16) - 8) ** 2 * 0.6 + ((YY % 14) - 7) ** 2
    hx = shade(hx, 0.6 + 0.6 * (q > 30))
    save("f_floor", shade(hx, 0.85 + 0.25 * value_noise(N, 8, 904)))
    lb = metal(905, (200, 210, 205), seams=(0, 32), rivets=True)
    lb[8:24, 8:24] = col(20, 40, 30)
    lb[12:20, 10:22] = col(60, 255, 120) * 0.8
    save("f_lab", lb)
    v = fill((20, 30, 26))
    vat = np.abs(XX - 32) < 22
    vg = np.clip(1 - np.abs(XX - 32) / 22, 0, 1)
    v[vat] = (col(40, 200, 90) * (0.4 + 0.6 * vg[vat])[:, None])
    body, holes, _eyes = gorb_face_mask(32, 34, 13)
    v = paste_mask(v, body * 0.8, (20, 90, 40))
    v = paste_mask(v, holes * body * 0.8, (200, 255, 200))
    bub = (white(N, 906) > 0.97) & vat
    v[bub] = col(220, 255, 220)
    v[0:6, :] = col(150, 150, 160); v[-6:, :] = col(150, 150, 160)
    v[6, :] *= 0.4
    save("f_vat", v)
    for i in range(4):
        s = tiles(907, [(230, 235, 230)], (150, 160, 150), n=8)
        s = text_panel("GORBINO\nUNIT\n%04d" % (i * 1111 + 23), "Silkscreen-Bold.ttf", 8, None, (30, 40, 30), base=s, spacing=3)
        save("f_stencil%d" % i, grime(s, 908 + i, 0.3))
    fp = fill((30, 34, 30))
    for y in range(0, N, 16):
        fp[y + 2:y + 12, :] = col(150, 160, 150) * np.cos((np.arange(10) - 4.5) / 6)[:, None, None]
    save("f_pipe", fp)
    fc = fill((200, 205, 200))
    fc[24:40, :] = col(230, 255, 220)
    fc[23, :] = col(80, 90, 80); fc[40, :] = col(80, 90, 80)
    save("f_ceiling", fc, q=False)
    save("f_dark", metal(909, (40, 46, 50), seams=(0, 32)))
    ra = stripes_diag((200, 20, 20), (30, 10, 10), w=8)
    save("f_alert", ra)
    gl = fill((0, 20, 10))

    gl[:, :] = col(20, 120, 60) * (0.5 + 0.5 * np.sin(YY * 0.3)[..., None])
    save("f_glow", gl, q=False)


# ================================================================ level 6: snirby dimension
def dimension():
    fl = gradmap(value_noise(N, 6, 1000, 5), [(0, (120, 20, 50)), (0.6, (230, 100, 130)), (1, (255, 190, 200))])
    vn = value_noise(N, 8, 1001, 3)
    veins = (np.abs(vn - 0.5) < 0.025).astype(np.float32)
    fl = paste_mask(fl, veins, (90, 0, 60))
    vn2 = value_noise(N, 4, 1002, 3)
    fl = paste_mask(fl, (np.abs(vn2 - 0.5) < 0.02).astype(np.float32), (60, 40, 160))
    save("d_flesh", fl)
    ey = fill((120, 30, 70))
    ey = shade(ey, 0.7 + 0.4 * value_noise(N, 8, 1003))
    for (cx, cy, r_) in [(16, 16, 11), (48, 20, 9), (20, 48, 9), (48, 50, 12)]:
        rr = np.hypot(XX - cx, YY - cy)
        ey = paste_mask(ey, (rr < r_).astype(np.float32), (250, 240, 220))
        ey = paste_mask(ey, (rr < r_ * 0.5).astype(np.float32), (40, 220, 60))
        ey = paste_mask(ey, (rr < r_ * 0.25).astype(np.float32), (0, 0, 0))
        ey = paste_mask(ey, ((rr >= r_) & (rr < r_ + 1.2)).astype(np.float32), (60, 0, 30))
    save("d_eyes", ey)
    w = np.sin(XX * 0.2 + np.sin(YY * 0.15) * 3)
    ch = ((((XX + w * 4) // 8) + ((YY + w * 3) // 8)) % 2).astype(np.float32)
    save("d_checker", lerp(np.ones((N, N, 3)) * col(255, 0, 200), np.ones((N, N, 3)) * col(180, 255, 0), ch))
    stc = white(N, 1004)
    save("d_static", np.stack([stc, stc * 0.9, stc], -1), q=True)
    th = fill((90, 10, 30))
    for row in range(4):
        for k in range(8):
            x0 = k * 8 + (4 if row % 2 else 0)
            for i in range(8):
                hgt = int(12 * (1 - abs(i - 3.5) / 4))
                y0 = row * 16 + 2
                th[y0:y0 + hgt, (x0 + i) % N] = col(250, 245, 200) * (0.8 + 0.05 * i)
    save("d_teeth", th)
    ang = np.arctan2(YY - 32, XX - 32)
    rr = np.hypot(XX - 32, YY - 32)
    t = 0.5 + 0.5 * np.sin(ang * 4 + rr * 0.4)
    save("d_swirl", gradmap(t, [(0, (40, 0, 80)), (0.4, (255, 0, 160)), (0.7, (0, 255, 200)), (1, (255, 255, 120))]))
    gl = fill((20, 0, 30))
    fnt = font("Silkscreen-Bold.ttf", 8)
    glyphs = "SNIRB" * 6
    m = np.zeros((N, N), np.float32)
    for row in range(5):
        m = np.maximum(m, text_layer((N, N), glyphs[row:row + 6], fnt, anchor_xy=(1 - row * 3, row * 13)))
    gl = paste_mask(gl, (m > 0.5).astype(np.float32), (180, 255, 0))
    save("d_glyph", gl)
    vd = fill((10, 0, 20))
    st = white(N, 1005) > 0.97
    vd[st] = col(255, 200, 255)
    vd = np.clip(vd + value_noise(N, 4, 1006, 4)[..., None] * col(90, 0, 120), 0, 1)
    save("d_void", vd)
    sf = fill((200, 255, 0))
    for (cx, cy) in [(16, 16), (48, 48)]:
        rr = np.hypot((XX - cx) * 0.8, YY - cy)
        sf = paste_mask(sf, (rr < 12).astype(np.float32), (200, 160, 230))
        sf = paste_mask(sf, ((np.abs(YY - cy) < 2) & (XX > cx) & (XX < cx + 16)).astype(np.float32), (200, 160, 230))
        sf = paste_mask(sf, (np.hypot(XX - cx + 4, YY - cy + 3) < 2).astype(np.float32), (0, 0, 0))
        sf = paste_mask(sf, (np.hypot(XX - cx + 4 + 8, YY - cy + 3) < 2).astype(np.float32), (0, 0, 0))
    save("d_snirbface", sf)
    oz = gradmap(value_noise(N, 6, 1007, 5), [(0, (40, 0, 60)), (0.6, (150, 60, 220)), (1, (240, 180, 255))])
    save("d_ooze", oz)
    save("d_meat", rock(1008, [(0, (80, 0, 20)), (0.5, (200, 40, 60)), (1, (255, 160, 140))], cells=12))


# ================================================================ fever (episode 2)
def fever():
    """GORB FEVER: loud, flat, high-contrast surfaces - glazed tiles, neon
    grids, glowing light panels, walls running with sweat - meant to be
    graded hard into one colour per level."""
    r = rng(2000)
    # glazed tiles: yellow, red, white; big squares, dark grout, a glint
    for name, base, grout in [("fv_tile_y", (240, 210, 40), (60, 40, 0)), ("fv_tile_r", (220, 30, 40), (50, 0, 10)),
                              ("fv_tile_w", (235, 232, 220), (40, 30, 40))]:
        img = fill(base)
        n = value_noise(N, 6, 2001 + len(name), 3)
        img = shade(img, 0.88 + 0.2 * n)
        for k in range(0, N, 16):
            img[k:k + 2, :] = col(*grout)
            img[:, k:k + 2] = col(*grout)
        for ty in range(0, N, 16):
            for tx in range(0, N, 16):
                img[ty + 3:ty + 5, tx + 3:tx + 8] = np.clip(img[ty + 3:ty + 5, tx + 3:tx + 8] + 0.35, 0, 1)
                if r.random() < 0.18:
                    # a cracked tile
                    cx = tx + int(r.integers(4, 12))
                    for yy_ in range(ty + 2, ty + 15):
                        cx = int(np.clip(cx + r.integers(-1, 2), tx + 2, tx + 14))
                        img[yy_, cx] = col(*grout)
        save(name, img)
    # concrete: pale cream with heavy dither speckle and a stain or two
    cc = gradmap(value_noise(N, 5, 2010, 5), [(0, (170, 160, 130)), (1, (235, 228, 200))])
    sp = white(N, 2011)
    cc[sp > 0.93] *= 0.7
    cc[sp < 0.04] = np.clip(cc[sp < 0.04] + 0.15, 0, 1)
    save("fv_concrete", cc)
    # hazard stripes, yellow and black
    save("fv_stripe", stripes_diag((250, 220, 20), (20, 16, 10), 8))
    # neon grids on black
    for name, c in [("fv_grid_c", (60, 240, 230)), ("fv_grid_m", (255, 70, 220))]:
        img = fill((10, 6, 16))
        g = ((XX % 16) < 1.5) | ((YY % 16) < 1.5)
        img[g] = col(*c)
        glow = ((XX % 16) < 3.5) | ((YY % 16) < 3.5)
        img[glow & ~g] = col(*c) * 0.35
        save(name, img)
    # glowing light panels: a dark frame round a hot band (these light up)
    for name, c in [("fv_glow_r", (255, 70, 40)), ("fv_glow_c", (80, 255, 240)), ("fv_glow_y", (255, 240, 90))]:
        img = fill((26, 20, 30))
        img[6:58, 8:56] = col(*c) * 0.55
        img[12:52, 14:50] = col(*c)
        img[24:40, 18:46] = np.clip(col(*c) + 0.3, 0, 1)
        bevel_rect(img, 8, 6, 56, 58, 0.15, 0.4, 2)
        save(name, img)
    # ceiling with long light strips
    cl = fill((30, 26, 34))
    cl = shade(cl, 0.85 + 0.25 * value_noise(N, 8, 2020, 3))
    cl[28:36, :] = col(255, 250, 220)
    cl[26:28, :] = col(120, 110, 90)
    cl[36:38, :] = col(120, 110, 90)
    save("fv_ceil", cl)
    # sweat: purple wall running with bright yellow-green drips
    sw = gradmap(value_noise(N, 6, 2030, 4), [(0, (40, 0, 60)), (1, (120, 40, 150))])
    for k in range(14):
        x = int(r.integers(0, N))
        y0 = int(r.integers(0, 20))
        ln = int(r.integers(18, 60))
        sw[y0:min(N, y0 + ln), x:x + 2] = col(200, 255, 40)
        sw[min(N - 3, y0 + ln - 3):min(N, y0 + ln), max(0, x - 1):x + 3] = col(230, 255, 120)
    save("fv_sweat", sw)
    # metal mesh floor with something glowing underneath
    mf = fill((40, 44, 52))
    holes = ((XX % 8) > 2) & ((YY % 8) > 2)
    mf[holes] = col(255, 90, 40) * (0.4 + 0.3 * value_noise(N, 4, 2040, 3)[holes][..., None])
    save("fv_mesh", mf)
    # floor checker, red and bone, big squares
    ch = (((XX // 16) + (YY // 16)) % 2).astype(np.float32)
    save("fv_check", lerp(fill((210, 20, 40)), fill((240, 232, 214)), ch))
    # magenta bricks
    save("fv_brick_m", bricks(2050, (200, 40, 170), (40, 0, 40), bw=16, bh=8, var=0.15))
    # bone wall with gum-red grout
    save("fv_bone", bricks(2060, (235, 225, 195), (150, 20, 50), bw=32, bh=10, var=0.08, noise=0.15))
    # a door striped with chevrons
    chev = ((np.abs(XX - 32) + YY) // 8 % 2).astype(np.float32)
    dr = lerp(fill((250, 70, 40)), fill((26, 20, 30)), chev)
    bevel_rect(dr, 0, 0, N, N, 0.2, 0.4, 3)
    save("fv_door", dr)
    # signs
    save("fv_sign_down", text_panel("DOWN", "Anton-Regular.ttf", 26, (250, 220, 20), (20, 10, 10), shadow=(140, 90, 0)))
    save("fv_sign_run", text_panel("KEEP\nGOING", "Anton-Regular.ttf", 20, (220, 20, 40), (250, 245, 230), spacing=-2))
    save("fv_sign_gorb", text_panel("GORB", "Anton-Regular.ttf", 28, (20, 10, 30), (80, 255, 240), outline_c=(255, 70, 220)))
    # skies: a red fever sky with a white-hot sun; a magenta and teal one
    W, H = 256, 128
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    t = yy / H
    sky = gradmap(t, [(0, (60, 0, 10)), (0.5, (230, 40, 30)), (0.8, (255, 170, 60)), (1, (255, 240, 160))])
    bands = (np.sin(yy * 0.5) > 0.8) & (yy > 70)
    sky[bands] *= 0.7
    sun = np.hypot(xx - 160, (yy - 80) * 1.1) < 22
    sky[sun] = col(255, 252, 235)
    sky[(np.hypot(xx - 160, (yy - 80) * 1.1) < 24) & ~sun] = col(255, 200, 120)
    to_image(sky).save(os.path.join(OUT, "sky_fever.png"))
    n = value_noise(W, 6, 2070, 4)[:H, :]
    sky = gradmap(t + (n - 0.5) * 0.4, [(0, (20, 0, 40)), (0.45, (220, 30, 200)), (0.7, (40, 220, 220)), (1, (240, 255, 250))])
    st = white(W, 2071, H) > 0.985
    sky[st & (yy < 60)] = col(255, 255, 255)
    to_image(sky).save(os.path.join(OUT, "sky_fever2.png"))


# ================================================================ skies (256x128)
def skies():
    W, H = 256, 128
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)

    def noise_wide(seed, cells=8, octaves=4):
        n = value_noise(W, cells, seed, octaves)
        return n[:H, :]

    def hills(img, seed, color, base_y, amp, freq, bumps=True):
        r = rng(seed)
        ph = r.random() * 6
        h = base_y - amp * (0.5 + 0.5 * np.sin(np.arange(W) * freq * 2 * np.pi / W + ph)) \
            - amp * 0.4 * (0.5 + 0.5 * np.sin(np.arange(W) * freq * 3 * 2 * np.pi / W + ph * 2))
        m = yy > h[None, :]
        img[m] = col(*color)
        return img, h

    # village: sickly yellow-green sky with gorbino hills
    t = yy / H
    sky = gradmap(t + noise_wide(1100) * 0.15, [(0, (130, 200, 255)), (0.5, (230, 250, 160)), (1, (255, 200, 120))])
    cl = noise_wide(1101, 8, 5)
    sky = paste_mask(sky, np.clip((cl - 0.55) * 4, 0, 1) * (yy < 70), (255, 255, 240))
    sky, h = hills(sky, 1102, (60, 140, 60), 110, 18, 3)
    sky, _ = hills(sky, 1103, (40, 100, 40), 124, 10, 5)
    to_image(sky).save(os.path.join(OUT, "sky_village.png"))
    # industrial smog
    sky = gradmap(t + noise_wide(1110) * 0.3, [(0, (60, 30, 20)), (0.5, (200, 110, 40)), (1, (250, 200, 90))])
    r = rng(1111)
    x = 0
    while x < W:
        w = int(r.integers(8, 30)); h_ = int(r.integers(20, 70))
        sky[H - h_:, x:x + w] = col(30, 22, 20)
        if r.random() < 0.4:
            sx = x + w // 2
            sky[H - h_ - 30:H - h_, sx - 2:sx + 2] = col(30, 22, 20)
        for wy in range(H - h_ + 4, H, 6):
            for wx in range(x + 2, x + w - 2, 5):
                if r.random() < 0.3:
                    sky[wy:wy + 2, wx:wx + 2] = col(255, 200, 60)
        x += w + int(r.integers(0, 10))
    to_image(sky).save(os.path.join(OUT, "sky_smog.png"))
    # HQ night
    sky = gradmap(t + noise_wide(1120) * 0.1, [(0, (5, 0, 20)), (0.7, (40, 10, 70)), (1, (120, 30, 90))])
    stars = (white(W, 1121, H) > 0.985) & (yy < 80)
    sky[stars] = col(255, 255, 220)
    r = rng(1122)
    x = 0
    while x < W:
        w = int(r.integers(10, 26)); h_ = int(r.integers(30, 90))
        sky[H - h_:, x:x + w] = col(16, 10, 30)
        for wy in range(H - h_ + 3, H, 4):
            for wx in range(x + 2, x + w - 1, 3):
                if r.random() < 0.35:
                    sky[wy:wy + 2, wx] = col(*[(255, 220, 120), (120, 255, 220), (255, 80, 200)][r.integers(3)])
        x += w + int(r.integers(1, 6))
    to_image(sky).save(os.path.join(OUT, "sky_night.png"))
    # snirby void
    ang = xx / W * 2 * np.pi
    sw = 0.5 + 0.5 * np.sin(ang * 6 + yy * 0.12 + noise_wide(1130) * 6)
    sky = gradmap(sw, [(0, (20, 0, 40)), (0.5, (150, 0, 160)), (0.8, (255, 60, 200)), (1, (200, 255, 0))])
    for cx in range(16, W, 64):
        cy = 50 + (cx % 3) * 10
        rr = np.hypot(xx - cx, (yy - cy) * 1.6)
        sky = paste_mask(sky, (rr < 12).astype(np.float32), (255, 250, 230))
        sky = paste_mask(sky, (rr < 6).astype(np.float32), (40, 230, 60))
        sky = paste_mask(sky, (rr < 3).astype(np.float32), (0, 0, 0))
    to_image(sky).save(os.path.join(OUT, "sky_void.png"))
    # mines/facility ambient sky fallback (dark)
    sky = gradmap(t, [(0, (0, 0, 0)), (1, (30, 20, 30))])
    to_image(sky).save(os.path.join(OUT, "sky_dark.png"))


if __name__ == "__main__":
    common()
    pickups()
    village()
    industrial()
    mines()
    hq()
    facility()
    dimension()
    fever()
    skies()
    print("textures written:", _count[0] + 5)
