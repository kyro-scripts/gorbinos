"""Effect sprites, UI art, logo and baked bitmap fonts for Gorbino's Quest.

Run: python3 tools/gen_sprites.py
"""
import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from texlib import *

SPR = os.path.join(ROOT, "assets", "sprites")
UI = os.path.join(ROOT, "assets", "ui")
FNT = os.path.join(ROOT, "assets", "fonts")
os.makedirs(SPR, exist_ok=True)
os.makedirs(UI, exist_ok=True)


def rgba(arr_rgb, alpha):
    a = np.clip(alpha, 0, 1)
    out = np.concatenate([np.clip(arr_rgb, 0, 1), a[..., None]], -1)
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def strip(frames):
    w, h = frames[0].size
    s = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.paste(f, (i * w, 0))
    return s


def blob_frame(size, seed, t, stops, rad=0.45, lumpy=0.25, hard=True):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2
    n = value_noise(size, 6, seed, 4)
    r = np.hypot(xx - c, yy - c) / size
    radius = rad * (0.6 + 0.4 * t) + (n - 0.5) * lumpy
    inside = r < radius
    heat = np.clip(1 - r / np.maximum(radius, 1e-3), 0, 1) * (1 - t * 0.7) + n * 0.3
    col_ = gradmap(np.clip(heat, 0, 1), stops)
    alpha = inside.astype(np.float32)
    if hard:
        # crunchy dither on the edge
        bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
        b = np.tile(bayer, (size // 4 + 1, size // 4 + 1))[:size, :size]
        edge = np.clip((radius - r) / 0.06, 0, 1)
        alpha = (edge > b).astype(np.float32) * inside
    return col_, alpha


def explosion():
    frames = []
    for i in range(8):
        t = i / 7
        c, a = blob_frame(64, 2000 + i, t, [(0, (60, 10, 0)), (0.3, (220, 50, 10)), (0.6, (255, 160, 20)), (0.85, (255, 240, 120)), (1, (255, 255, 255))],
                          rad=0.22 + 0.25 * min(1, t * 2.2), lumpy=0.18)
        if t > 0.55:  # turning to smoke
            k = (t - 0.55) / 0.45
            c = c * (1 - k) + np.array([0.2, 0.18, 0.18]) * k
        frames.append(rgba(c, a))
    strip(frames).save(os.path.join(SPR, "explosion.png"))
    frames = []
    for i in range(6):
        t = i / 5
        c, a = blob_frame(64, 2100 + i, t, [(0, (90, 0, 140)), (0.4, (255, 40, 220)), (0.8, (200, 255, 40)), (1, (255, 255, 255))],
                          rad=0.2 + 0.25 * min(1, t * 2), lumpy=0.2)
        frames.append(rgba(c, a))
    strip(frames).save(os.path.join(SPR, "explosion_plasma.png"))


def puffs():
    frames = []
    for i in range(4):
        t = i / 3
        c, a = blob_frame(32, 2200 + i, t, [(0, (60, 60, 60)), (1, (220, 220, 210))], rad=0.18 + 0.2 * t, lumpy=0.2)
        frames.append(rgba(c, a))
    strip(frames).save(os.path.join(SPR, "puff.png"))
    frames = []
    for i in range(4):
        t = i / 3
        c, a = blob_frame(32, 2300 + i, t, [(0, (255, 120, 0)), (0.6, (255, 240, 120)), (1, (255, 255, 255))], rad=0.25 - 0.15 * t, lumpy=0.25)
        frames.append(rgba(c, a))
    strip(frames).save(os.path.join(SPR, "spark.png"))
    frames = []
    for i in range(6):
        t = i / 5
        c, a = blob_frame(64, 2400 + i, t, [(0, (0, 80, 60)), (0.5, (60, 255, 200)), (1, (255, 255, 255))], rad=0.15 + 0.3 * math.sin(t * math.pi), lumpy=0.3)
        frames.append(rgba(c, a))
    strip(frames).save(os.path.join(SPR, "telefog.png"))


def flashes():
    frames = []
    for i, (spikes, seed) in enumerate([(5, 1), (7, 2), (6, 3)]):
        s = 64
        yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
        c = (s - 1) / 2
        ang = np.arctan2(yy - c, xx - c)
        r = np.hypot(xx - c, yy - c) / (s / 2)
        rr = 0.35 + 0.55 * np.abs(np.cos(ang * spikes / 2 + seed)) ** 3
        n = value_noise(s, 8, 2500 + i)
        shape = r < rr * (0.8 + 0.4 * n)
        heat = np.clip(1 - r / rr, 0, 1)
        colr = gradmap(heat, [(0, (255, 90, 0)), (0.4, (255, 220, 60)), (1, (255, 255, 240))])
        frames.append(rgba(colr, shape.astype(np.float32)))
    strip(frames).save(os.path.join(SPR, "muzzle.png"))
    frames = []
    for i, (spikes, seed) in enumerate([(4, 1), (6, 2), (5, 3)]):
        s = 64
        yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
        c = (s - 1) / 2
        ang = np.arctan2(yy - c, xx - c)
        r = np.hypot(xx - c, yy - c) / (s / 2)
        rr = 0.4 + 0.5 * np.abs(np.cos(ang * spikes / 2 + seed)) ** 2
        shape = r < rr
        heat = np.clip(1 - r / rr, 0, 1)
        colr = gradmap(heat, [(0, (0, 120, 255)), (0.5, (80, 255, 255)), (1, (255, 255, 255))])
        frames.append(rgba(colr, shape.astype(np.float32)))
    strip(frames).save(os.path.join(SPR, "muzzle_plasma.png"))


def projectiles():
    def orb(name, stops, seed, size=32, n=2):
        frames = []
        for i in range(n):
            c, a = blob_frame(size, seed + i, 0.0, stops, rad=0.42, lumpy=0.15)
            frames.append(rgba(c, a))
        strip(frames).save(os.path.join(SPR, name + ".png"))
    orb("proj_plasma", [(0, (0, 60, 200)), (0.5, (40, 230, 255)), (1, (255, 255, 255))], 2600)
    orb("proj_green", [(0, (20, 80, 0)), (0.5, (120, 255, 30)), (1, (255, 255, 200))], 2610)
    orb("proj_spit", [(0, (60, 0, 80)), (0.5, (200, 120, 255)), (1, (255, 230, 255))], 2620)
    orb("proj_ice", [(0, (0, 30, 120)), (0.5, (90, 160, 255)), (1, (240, 250, 255))], 2630)
    orb("proj_purple", [(0, (80, 0, 60)), (0.5, (255, 40, 200)), (1, (255, 220, 250))], 2640)
    orb("proj_fire", [(0, (120, 20, 0)), (0.5, (255, 140, 0)), (1, (255, 255, 160))], 2650)


def splats():
    frames = []
    for i in range(4):
        s = 32
        yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
        n = value_noise(s, 4, 2700 + i, 3)
        r = np.hypot(xx - 15.5, yy - 15.5) / 16
        m = r < (0.45 + (n - 0.5) * 0.9)
        d = white(s, 2710 + i) > 0.9
        m = m | (d & (r < 0.95))
        shadev = 0.75 + 0.25 * n
        c = np.stack([shadev, shadev, shadev], -1)
        frames.append(rgba(c, m.astype(np.float32)))
    strip(frames).save(os.path.join(SPR, "splat.png"))
    # bullet hole
    s = 16
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    r = np.hypot(xx - 7.5, yy - 7.5)
    a = (r < 3.5).astype(np.float32) + (r < 5.5).astype(np.float32) * 0.5
    c = np.zeros((s, s, 3)) + 0.05
    rgba(c, np.clip(a, 0, 1)).save(os.path.join(SPR, "bullethole.png"))


def gorb_head(size, blink=False, color=(130, 230, 40)):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = size
    d.ellipse([1, 2, s - 2, s - 1], fill=(20, 30, 10, 255))
    d.ellipse([2, 3, s - 3, s - 2], fill=color + (255,))
    d.ellipse([4, 4, s * 0.6, s * 0.45], fill=tuple(min(255, c + 60) for c in color) + (255,))
    ey = int(s * 0.38)
    for ex in (int(s * 0.32), int(s * 0.68)):
        if blink:
            d.line([ex - 3, ey, ex + 3, ey], fill=(20, 20, 20, 255), width=2)
        else:
            d.ellipse([ex - 4, ey - 4, ex + 4, ey + 4], fill=(255, 255, 250, 255))
            d.ellipse([ex - 2, ey - 2, ex + 2, ey + 2], fill=(10, 10, 10, 255))
    my = int(s * 0.66)
    d.rectangle([s * 0.28, my, s * 0.72, my + 3], fill=(40, 0, 10, 255))
    d.rectangle([s * 0.32, my + 1, s * 0.68, my + 2], fill=(220, 40, 70, 255))
    return im


def ui_art():
    # menu cursor: gorbino head (2 frames: eyes open / blink)
    strip([gorb_head(24), gorb_head(24, True)]).save(os.path.join(UI, "cursor.png"))
    gorb_head(64).save(os.path.join(UI, "gorb_icon.png"))
    gorb_head(128).save(os.path.join(UI, "gorb_big.png"))
    # crosshairs (white, tinted at runtime)
    for i, pts in enumerate([
        [(7, 3, 7, 5), (7, 9, 7, 11), (3, 7, 5, 7), (9, 7, 11, 7)],
        [(7, 7, 7, 7)],
        [(6, 6, 8, 8)],
    ]):
        im = Image.new("RGBA", (15, 15), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        for (x0, y0, x1, y1) in pts:
            d.rectangle([x0 - 1, y0 - 1, x1 + 1, y1 + 1], fill=(0, 0, 0, 200))
        for (x0, y0, x1, y1) in pts:
            d.rectangle([x0, y0, x1, y1], fill=(255, 255, 255, 255))
        im.save(os.path.join(UI, "crosshair%d.png" % i))
    # HUD bar background (tileable 128x48): veined teal marble with flesh frame
    W, H = 128, 48
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    n = value_noise(128, 4, 2800, 5)[:H]
    t = 0.5 + 0.5 * np.sin((xx * 0.08 + yy * 0.05) + n * 8)
    bar = gradmap(t ** 2, [(0, (10, 50, 50)), (0.6, (30, 110, 100)), (1, (170, 240, 210))])
    to_image(bar).save(os.path.join(UI, "hud_bg.png"))
    fr = gradmap(value_noise(128, 8, 2801)[:16, :128] if False else value_noise(64, 8, 2801), [(0, (120, 40, 50)), (1, (240, 150, 140))])
    to_image(fr).save(os.path.join(UI, "hud_frame.png"))
    # menu background tile: clashing checker + slime
    s = 64
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    w = np.sin(xx * 0.2 + np.sin(yy * 0.1) * 2)
    ch = ((((xx + w * 3) // 16) + ((yy) // 16)) % 2).astype(np.float32)
    a = gradmap(value_noise(s, 8, 2802), [(0, (40, 10, 50)), (1, (90, 30, 90))])
    b = gradmap(value_noise(s, 8, 2803), [(0, (10, 40, 30)), (1, (30, 90, 60))])
    to_image(a * (1 - ch[..., None]) + b * ch[..., None]).save(os.path.join(UI, "menu_bg.png"))
    # rank letters + stamps
    for letter, c1, c2 in [("S", (255, 240, 60), (255, 60, 0)), ("A", (120, 255, 60), (0, 120, 40)),
                           ("B", (80, 220, 255), (20, 40, 200)), ("C", (255, 160, 220), (160, 20, 120)),
                           ("D", (200, 200, 200), (80, 80, 80))]:
        big_text_image(letter, "Bungee-Regular.ttf", 72, c1, c2, os.path.join(UI, "rank_%s.png" % letter))
    big_text_image("GORBED", "Bungee-Regular.ttf", 56, (255, 80, 60), (90, 0, 0), os.path.join(UI, "stamp_gorbed.png"), wobble=True)
    big_text_image("CLEARED", "Bungee-Regular.ttf", 40, (200, 255, 60), (20, 90, 0), os.path.join(UI, "stamp_cleared.png"))
    # fictional publisher splash logo
    publisher_logo()


def big_text_image(text, fname, size, c1, c2, path, wobble=False, outline_px=3, shadow=4):
    f = font(fname, size)
    tmp = Image.new("L", (size * len(text) + 40, size * 2), 0)
    d = ImageDraw.Draw(tmp)
    bb = d.textbbox((0, 0), text, font=f)
    w, h = bb[2] - bb[0] + outline_px * 2 + shadow + 4, bb[3] - bb[1] + outline_px * 2 + shadow + 4
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).text((outline_px - bb[0] + 2, outline_px - bb[1] + 2), text, font=f, fill=255)
    mask = (np.asarray(m) > 127)
    if wobble:
        yy, xx = np.mgrid[0:h, 0:w]
        shift = (np.sin(xx * 0.15) * 2).astype(int)
        mask = np.array([[mask[(y + shift[y, x]) % h, x] for x in range(w)] for y in range(h)])
    H, W = mask.shape
    yy = np.mgrid[0:H, 0:W][0].astype(np.float32)
    grad = gradmap(yy / H, [(0, tuple(min(255, int(c * 1.0)) for c in c1)), (0.55, c1), (1, c2)])
    n = value_noise(max(W, H) + (4 - max(W, H) % 4), 8, 2900)[:H, :W]
    grad = shade(grad, 0.8 + 0.4 * n)
    out = np.zeros((H, W, 4), np.float32)
    # shadow
    sm = np.zeros_like(mask)
    sm[shadow:, shadow:] = mask[:-shadow, :-shadow]
    out[sm] = [0.05, 0.0, 0.05, 1]
    o = mask.copy()
    for dy in range(-outline_px, outline_px + 1):
        for dx in range(-outline_px, outline_px + 1):
            o |= np.roll(np.roll(mask, dy, 0), dx, 1)
    out[o] = [0.06, 0.02, 0.04, 1]
    out[mask, :3] = grad[mask]
    out[mask, 3] = 1
    # highlight line on top edges
    top = mask & ~np.roll(mask, 1, 0)
    out[top, :3] = np.clip(out[top, :3] + 0.35, 0, 1)
    Image.fromarray((out * 255).astype(np.uint8), "RGBA").save(path)


def publisher_logo():
    W, H = 256, 96
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # gland-like blob symbol
    d.ellipse([8, 12, 80, 84], fill=(230, 40, 120, 255), outline=(40, 0, 20, 255), width=3)
    d.ellipse([24, 26, 64, 66], fill=(255, 220, 40, 255), outline=(40, 0, 20, 255), width=2)
    d.ellipse([38, 40, 50, 52], fill=(20, 0, 10, 255))
    f = font("Anton-Regular.ttf", 34)
    d.text((92, 8), "GLANDCORE", font=f, fill=(255, 220, 40, 255), stroke_width=2, stroke_fill=(40, 0, 20, 255))
    f2 = font("Silkscreen-Bold.ttf", 16)
    d.text((94, 56), "SOFTWARE", font=f2, fill=(230, 40, 120, 255), stroke_width=1, stroke_fill=(40, 0, 20, 255))
    im.save(os.path.join(UI, "publisher.png"))


def title_logo():
    """GORBINO'S QUEST logo: chunky extruded gradient letters."""
    f1 = font("Bungee-Regular.ttf", 64)
    f2 = font("Bungee-Regular.ttf", 46)
    W, H = 600, 190
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    t1 = "GORBINO'S"
    t2 = "QUEST"
    b1 = d.textbbox((0, 0), t1, font=f1)
    b2 = d.textbbox((0, 0), t2, font=f2)
    d.text(((W - (b1[2] - b1[0])) // 2 - b1[0], 8 - b1[1]), t1, font=f1, fill=255)
    d.text(((W - (b2[2] - b2[0])) // 2 - b2[0], 96 - b2[1]), t2, font=f2, fill=255)
    mask = np.asarray(m) > 127
    # slight perspective wobble: bulge rows
    out = np.zeros((H, W, 4), np.float32)
    # extrusion (dark magenta) going down-right
    for k in range(10, 0, -1):
        sh = np.zeros_like(mask)
        sh[k:, k // 2:] = mask[:-k, :W - k // 2]
        shade_c = np.array([0.25 + k * 0.01, 0.0, 0.2 + k * 0.02, 1.0])
        out[sh] = shade_c
    o = mask.copy()
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            if dx * dx + dy * dy <= 10:
                o |= np.roll(np.roll(mask, dy, 0), dx, 1)
    out[o & ~mask] = [0.04, 0.0, 0.06, 1]
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    band = (yy % 90) / 90.0
    grad = gradmap(band, [(0, (255, 255, 160)), (0.35, (200, 255, 30)), (0.6, (40, 200, 40)), (0.61, (255, 220, 0)), (1, (255, 90, 0))])
    n = value_noise(600 + 8, 16, 3000)[:H, :W]
    grad = shade(grad, 0.85 + 0.3 * n)
    out[mask, :3] = grad[mask]
    out[mask, 3] = 1
    top = mask & ~np.roll(mask, 2, 0)
    out[top, :3] = np.clip(out[top, :3] + 0.3, 0, 1)
    Image.fromarray((out * 255).astype(np.uint8), "RGBA").save(os.path.join(UI, "logo.png"))


# ---------------------------------------------------------------- bitmap fonts
CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 !?.,:;'\"-+%/()#*=_<>[]&$@"


def make_bmfont(name, ttf, size, stops, outline_px=2, shadow=2, upper=True, chars=CHARS, extra_h=0):
    f = font(ttf, size)
    glyphs = []
    ascent, descent = f.getmetrics()
    line_h = ascent + descent + outline_px * 2 + shadow + extra_h
    for ch in chars:
        render_ch = ch.upper() if (upper and ch.isalpha()) else ch
        if ch == " ":
            glyphs.append((ch, None, 0, 0, max(4, size // 3) + outline_px))
            continue
        bb = f.getbbox(render_ch)
        adv = f.getlength(render_ch)
        w = bb[2] - bb[0] + outline_px * 2 + shadow + 1
        h = bb[3] - bb[1] + outline_px * 2 + shadow + 1
        m = Image.new("L", (w, h), 0)
        ImageDraw.Draw(m).text((outline_px - bb[0], outline_px - bb[1]), render_ch, font=f, fill=255)
        mask = np.asarray(m) > 110
        out = np.zeros((h, w, 4), np.float32)
        sm = np.zeros_like(mask)
        if shadow:
            sm[shadow:, shadow:] = mask[:-shadow, :-shadow]
            out[sm] = [0, 0, 0, 0.85]
        o = mask.copy()
        for dy in range(-outline_px, outline_px + 1):
            for dx in range(-outline_px, outline_px + 1):
                o |= np.roll(np.roll(mask, dy, 0), dx, 1)
        out[o & ~mask] = [0.05, 0.0, 0.05, 1]
        # gradient by absolute glyph-space y so all letters share it
        yy = (np.mgrid[0:h, 0:w][0] + bb[1] - outline_px).astype(np.float32) / max(1, ascent)
        g = gradmap(np.clip(yy, 0, 1), stops)
        out[mask, :3] = g[mask]
        out[mask, 3] = 1
        glyphs.append((ch, out, bb[0] - outline_px, bb[1] - outline_px, int(round(adv)) + outline_px))
    # pack
    atlas_w = 512
    x = y = 0
    row_h = 0
    placed = []
    for ch, img, xo, yo, adv in glyphs:
        if img is None:
            placed.append((ch, 0, 0, 0, 0, 0, 0, adv))
            continue
        h, w = img.shape[:2]
        if x + w + 1 > atlas_w:
            x = 0
            y += row_h + 1
            row_h = 0
        placed.append((ch, x, y, w, h, xo, yo, adv))
        x += w + 1
        row_h = max(row_h, h)
    atlas_h = y + row_h + 1
    atlas_h = 1 << (atlas_h - 1).bit_length()
    atlas = np.zeros((atlas_h, atlas_w, 4), np.float32)
    gi = 0
    for (ch, img, xo, yo, adv), p in zip(glyphs, placed):
        if img is None:
            continue
        _, px, py, w, h = p[:5]
        atlas[py:py + h, px:px + w] = img
    Image.fromarray((atlas * 255).astype(np.uint8), "RGBA").save(os.path.join(FNT, name + ".png"))
    lines = [
        'info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=1,1' % (name, size),
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0" % (line_h, ascent + outline_px, atlas_w, atlas_h),
        'page id=0 file="%s.png"' % name,
        "chars count=%d" % len(placed),
    ]
    for ch, px, py, w, h, xo, yo, adv in placed:
        lines.append("char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d xadvance=%d page=0 chnl=15" % (ord(ch), px, py, w, h, xo, yo, adv))
    with open(os.path.join(FNT, name + ".fnt"), "w") as fh:
        fh.write("\n".join(lines) + "\n")


def fonts():
    make_bmfont("menufont", "Bungee-Regular.ttf", 20, [(0, (255, 255, 170)), (0.45, (255, 210, 30)), (0.75, (255, 110, 10)), (1, (200, 30, 0))])
    make_bmfont("menufont_hi", "Bungee-Regular.ttf", 20, [(0, (240, 255, 220)), (0.45, (160, 255, 40)), (1, (20, 140, 40))])
    make_bmfont("menufont_dim", "Bungee-Regular.ttf", 20, [(0, (200, 190, 210)), (1, (90, 70, 110))])
    make_bmfont("bigfont", "Bungee-Regular.ttf", 32, [(0, (255, 255, 200)), (0.5, (255, 90, 200)), (1, (110, 0, 120))], outline_px=3, shadow=3)
    make_bmfont("hudfont", "Anton-Regular.ttf", 28, [(0, (255, 255, 160)), (0.5, (255, 220, 0)), (1, (230, 90, 0))], outline_px=2, shadow=2,
                chars="0123456789%/-+ ABCDEFGHIJKLMNOPQRSTUVWXYZ")


if __name__ == "__main__":
    explosion()
    puffs()
    flashes()
    projectiles()
    splats()
    ui_art()
    title_logo()
    fonts()
    print("sprites/ui/fonts done")
