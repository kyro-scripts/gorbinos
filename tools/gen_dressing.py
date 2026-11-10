"""Set-dressing textures: the posters, signs, graffiti and prop surfaces that
fill the levels with stuff to look at (scripts/level/dressing.gd uses them).

  dr_poster_*      64x96 propaganda, ads and missing-creature notices
  dr_sign_*        128x32 wayfinding and warning signs, themed per level
  dr_graf_*        64x64 RGBA spray paint (alpha cut out)
  dr_cardboard, dr_books, dr_vending, dr_screen*, dr_fabric, dr_paper,
  dr_cabinet, dr_locker, dr_crt                     prop surfaces

Run: python3 tools/gen_dressing.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw
from texlib import (ROOT, rng, value_noise, quantize, to_image, font, text_layer,
                    paste_mask, outline, shade, col)

OUT = os.path.join(ROOT, "assets", "textures")


def fill(c, h, w):
    return np.ones((h, w, 3), np.float32) * col(*c)


def save(name, a, q=True):
    to_image(a, q).save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


def save_rgba(name, rgb, alpha):
    rgb = quantize(rgb, False)
    a = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
    im = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB")
    im.putalpha(Image.fromarray(a, "L"))
    im.save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


def grime(img, seed, amt=0.3):
    h, w = img.shape[:2]
    s = max(h, w)
    n = value_noise(s, 5, seed, 4)[:h, :w]
    yy = np.mgrid[0:h, 0:w][0].astype(np.float32)
    streak = value_noise(s, 24, seed + 3, 1)[:h, :w] * (yy / h)
    return shade(img, 1 - amt * (n * 0.7 + streak * 0.5))


def text(img, txt, fname, size, color, xy=None, spacing=0, stroke=None, box=None):
    """Draw txt into img (float HxWx3). box = (x0, y0, x1, y1) to centre in."""
    h, w = img.shape[:2]
    if box is None:
        box = (0, 0, w, h)
    bw, bh = box[2] - box[0], box[3] - box[1]
    m = text_layer((bw, bh), txt, font(fname, size), spacing=spacing,
                   anchor_xy=None if xy is None else (xy[0] - box[0], xy[1] - box[1]))
    m = (m > 0.45).astype(np.float32)
    full = np.zeros((h, w), np.float32)
    full[box[1]:box[3], box[0]:box[2]] = m
    if stroke is not None:
        img = paste_mask(img, outline(full, 1), stroke)
    return paste_mask(img, full, color)


def border(img, c, t=2):
    img[:t, :] = col(*c); img[-t:, :] = col(*c); img[:, :t] = col(*c); img[:, -t:] = col(*c)
    return img


def tape_corners(img, seed):
    r = rng(seed)
    h, w = img.shape[:2]
    for (x, y) in [(0, 0), (w - 10, 0), (0, h - 6), (w - 10, h - 6)]:
        if r.random() < 0.7:
            img[y:y + 6, x:x + 10] = img[y:y + 6, x:x + 10] * 0.4 + col(225, 215, 170) * 0.6
    return img


def gorb_icon(img, cx, cy, r, body, eye):
    """A little Gorbino mascot: domed head, two eyes, a fringe of feet."""
    h, w = img.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    head = ((xx - cx) / r) ** 2 + ((yy - cy) / (r * 1.05)) ** 2 < 1
    img[head] = col(*body)
    for k in range(5):
        fx = cx + (k - 2) * r * 0.42
        foot = ((xx - fx) / (r * 0.24)) ** 2 + ((yy - (cy + r * 0.95)) / (r * 0.22)) ** 2 < 1
        img[foot] = col(*body)
    for sx in (-1, 1):
        e = ((xx - (cx + sx * r * 0.38)) / (r * 0.2)) ** 2 + ((yy - (cy - r * 0.1)) / (r * 0.26)) ** 2 < 1
        img[e] = col(*eye)
        p = ((xx - (cx + sx * r * 0.38)) / (r * 0.08)) ** 2 + ((yy - (cy - r * 0.05)) / (r * 0.1)) ** 2 < 1
        img[p] = col(10, 10, 10)
    mouth = (np.abs(yy - (cy + r * 0.45)) < r * 0.07) & (np.abs(xx - cx) < r * 0.35)
    img[mouth] = col(30, 0, 10)
    return img


def snirby_photo(w, h):
    """Crop the Snirby face texture down to a mugshot."""
    src = Image.open(os.path.join(OUT, "cr_snirby_face.png")).convert("RGB")
    sw, sh = src.size
    crop = src.crop((int(sw * 0.15), int(sh * 0.1), int(sw * 0.85), int(sh * 0.9))).resize((w, h), Image.NEAREST)
    return np.asarray(crop).astype(np.float32) / 255.0


# ================================================================== posters
def posters():
    W, H = 64, 96
    BIG = "Anton-Regular.ttf"
    PX = "Silkscreen-Regular.ttf"
    TERM = "VT323-Regular.ttf"
    out = []

    def big(name, words, sub, bg, fg, subc, seed, size=19, spacing=-4):
        p = fill(bg, H, W)
        p = text(p, words, BIG, size, fg, box=(2, 3, W - 2, H - 20), spacing=spacing)
        p = text(p, sub, PX, 8, subc, box=(2, H - 20, W - 2, H - 4), spacing=-1)
        p = border(p, (20, 14, 14))
        out.append((name, grime(tape_corners(p, seed), seed, 0.25)))

    big("dr_poster_consume", "CONSUME\nOBEY\nREPEAT", "THE BOARD\nLOVES YOU", (250, 30, 130), (255, 255, 40), (40, 0, 30), 1, 17)
    big("dr_poster_smile", "SMILE", "YOU ARE\nWATCHED", (250, 240, 215), (210, 0, 30), (30, 30, 30), 2, 24)
    big("dr_poster_wage", "WAGE\nIS A\nFEELING", "FEEL IT\nHARDER", (30, 60, 220), (255, 255, 255), (255, 230, 0), 3, 18)
    big("dr_poster_dontlook", "DONT\nLOOK\nUP", "IT IS NOT\nTHERE", (12, 12, 12), (0, 255, 110), (120, 120, 120), 4, 20)
    big("dr_poster_report", "REPORT\nUNUSUAL\nHOPPING", "DIAL\n0800SNIRB", (255, 200, 0), (20, 20, 20), (150, 0, 0), 5, 14)
    big("dr_poster_pipes", "GOD\nIS IN\nTHE\nPIPES", "LISTEN", (90, 20, 20), (240, 200, 160), (255, 120, 80), 6, 15)
    big("dr_poster_norun", "NO\nRUNNING\nNO\nSCREAMING", "THANK YOU", (240, 240, 240), (20, 20, 20), (200, 0, 0), 7, 12, -2)
    big("dr_poster_buysell", "BUY\nSELL\nROT", "MARKETS\nNEVER SLEEP", (10, 90, 40), (180, 255, 120), (255, 255, 255), 8, 20)
    big("dr_poster_exit", "THERE\nIS NO\nEXIT", "ENJOY\nYOUR STAY", (120, 0, 140), (255, 140, 255), (255, 255, 0), 9, 16)
    big("dr_poster_hydrate", "HYDRATE", "NOW 9%\nJUICE", (0, 170, 210), (255, 255, 255), (255, 40, 120), 10, 16)

    # ad: Gorbino brand meat
    p = fill((255, 236, 200), H, W)
    p[0:22, :] = col(200, 20, 20)
    p = text(p, "GORBINO\nMEAT CO.", BIG, 11, (255, 240, 200), box=(2, 1, W - 2, 22), spacing=-3)
    p = gorb_icon(p, 32, 46, 15, (220, 120, 40), (255, 255, 255))
    p = text(p, "NOW 40%\nLESS BONE", PX, 8, (160, 0, 0), box=(2, 66, W - 2, 92), spacing=-1)
    out.append(("dr_poster_meat", grime(border(p, (120, 10, 10)), 11, 0.3)))

    # missing Snirby notice
    p = fill((235, 228, 205), H, W)
    p = text(p, "MISSING", BIG, 15, (20, 20, 20), box=(2, 1, W - 2, 20))
    ph = snirby_photo(40, 36)
    p[22:58, 12:52] = ph
    p[21, 11:53] = col(20, 20, 20); p[58, 11:53] = col(20, 20, 20)
    p[21:59, 11] = col(20, 20, 20); p[21:59, 52] = col(20, 20, 20)
    p = text(p, "LAST SEEN\nNEAR THE\nVATS", PX, 8, (40, 40, 40), box=(2, 61, W - 2, 93), spacing=-1)
    out.append(("dr_poster_missing", grime(tape_corners(p, 12), 12, 0.35)))

    # safety counter
    p = fill((30, 120, 40), H, W)
    p = text(p, "DAYS\nWITHOUT\nINCIDENT", PX, 8, (255, 255, 255), box=(2, 4, W - 2, 34), spacing=-1)
    p[38:78, 10:54] = col(250, 250, 240)
    p = text(p, "0", BIG, 34, (200, 0, 0), box=(10, 38, 54, 78))
    p = text(p, "STAY SAFE", PX, 8, (255, 230, 0), box=(2, 80, W - 2, 94))
    out.append(("dr_poster_safety", grime(border(p, (10, 40, 10)), 13, 0.3)))

    # employee of the month (it's a Gorbino)
    p = fill((40, 30, 25), H, W)
    p = text(p, "EMPLOYEE\nOF THE\nMONTH", PX, 8, (255, 210, 60), box=(2, 2, W - 2, 30), spacing=-1)
    p[32:74, 10:54] = col(130, 160, 200)
    p = gorb_icon(p, 32, 51, 13, (50, 110, 20), (255, 255, 255))
    p[32:74, 10] = col(255, 210, 60); p[32:74, 53] = col(255, 210, 60); p[32, 10:54] = col(255, 210, 60); p[73, 10:54] = col(255, 210, 60)
    p = text(p, "#00413", TERM, 16, (255, 255, 255), box=(2, 76, W - 2, 94))
    out.append(("dr_poster_employee", grime(p, 14, 0.25)))

    # Snirby Dimension tourism board
    p = fill((255, 120, 200), H, W)
    yy, xx = np.mgrid[0:H, 0:W]
    sw = (np.sin(np.hypot(xx - 32, yy - 40) * 0.6) > 0.3)
    p[sw] = col(120, 255, 240)
    p = text(p, "VISIT", BIG, 16, (30, 0, 60), box=(2, 2, W - 2, 22), stroke=(255, 255, 255))
    p = text(p, "SNIRBY\nDIMENSION", PX, 8, (30, 0, 60), box=(2, 66, W - 2, 92), spacing=-1, stroke=(255, 255, 255))
    out.append(("dr_poster_visit", grime(border(p, (60, 0, 80)), 15, 0.2)))

    for name, a in out:
        save(name, a)
    return [n for n, _ in out]


# ================================================================== signs
def signs():
    W, H = 128, 32
    PX = "Silkscreen-Regular.ttf"
    BIG = "Anton-Regular.ttf"
    specs = [
        # name, text, bg, fg, font, size
        ("dr_sign_breakroom", "BREAKROOM  >", (20, 90, 40), (255, 255, 255), PX, 16),
        ("dr_sign_regret", "< DEPT. OF REGRET", (230, 230, 220), (20, 20, 20), PX, 8),
        ("dr_sign_accounting", "ACCOUNTING  >", (30, 40, 120), (255, 255, 255), PX, 8),
        ("dr_sign_chute", "KEEP CHUTE CLEAR", (255, 200, 0), (20, 20, 20), PX, 8),
        ("dr_sign_max", "MAX 4 GORBINOS", (200, 20, 20), (255, 255, 255), PX, 8),
        ("dr_sign_shaft", "SHAFT 9  v", (90, 60, 30), (255, 220, 120), BIG, 18),
        ("dr_sign_canary", "CANARY DEAD - CONTINUE", (60, 40, 20), (255, 255, 200), PX, 8),
        ("dr_sign_contain", "CONTAINMENT", (230, 230, 230), (200, 0, 0), BIG, 20),
        ("dr_sign_dontfeed", "DO NOT FEED THE STAFF", (255, 255, 255), (0, 120, 60), PX, 8),
        ("dr_sign_wrongway", "WRONG WAY", (255, 0, 160), (255, 255, 0), BIG, 20),
        ("dr_sign_you", "YOU", (0, 0, 0), (255, 255, 255), BIG, 22),
        ("dr_sign_welcome", "GORBINO VILLAGE  POP. 0", (30, 80, 30), (255, 255, 255), PX, 8),
        ("dr_sign_wash", "EMPLOYEES MUST WASH", (240, 240, 240), (20, 20, 160), PX, 8),
        ("dr_sign_quiet", "QUIET: THINKING", (40, 40, 40), (255, 160, 0), PX, 8),
    ]
    names = []
    for i, (name, t, bg, fg, fn, fs) in enumerate(specs):
        p = fill(bg, H, W)
        p = text(p, t, fn, fs, fg, box=(3, 2, W - 3, H - 2))
        p = border(p, tuple(int(c * 0.5) for c in bg), 2)
        # screws
        for (x, y) in [(4, 4), (W - 5, 4), (4, H - 5), (W - 5, H - 5)]:
            p[y:y + 2, x:x + 2] = col(150, 150, 150)
        save(name, grime(p, 200 + i, 0.25))
        names.append(name)
    return names


# ================================================================== graffiti
def graffiti():
    S = 64
    specs = [
        ("dr_graf_help", "HELP", (255, 30, 30), "Anton-Regular.ttf", 26),
        ("dr_graf_gorb", "GORB\nLIVES", (40, 255, 80), "Anton-Regular.ttf", 20),
        ("dr_graf_hops", "IT\nHOPS", (255, 255, 255), "Anton-Regular.ttf", 22),
        ("dr_graf_snirb", "SNIRB\nWAS\nHERE", (255, 80, 220), "Anton-Regular.ttf", 15),
        ("dr_graf_nope", "NO", (255, 230, 0), "Anton-Regular.ttf", 36),
        ("dr_graf_eye", "", (0, 200, 255), None, 0),
    ]
    names = []
    for i, (name, t, c, fn, fs) in enumerate(specs):
        r = rng(300 + i)
        if t:
            m = text_layer((S, S), t, font(fn, fs), spacing=-3)
        else:
            # a crude spray-painted eye
            yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
            ring = np.abs(np.hypot((xx - 32) / 1.6, yy - 32) - 13) < 2.2
            pupil = np.hypot(xx - 32, yy - 32) < 6
            m = (ring | pupil).astype(np.float32)
        m = (m > 0.4).astype(np.float32)
        # spray: soft edge + speckle
        soft = m.copy()
        for _ in range(2):
            soft = np.maximum(soft, (np.roll(soft, 1, 0) + np.roll(soft, -1, 0) + np.roll(soft, 1, 1) + np.roll(soft, -1, 1)) * 0.22)
        speck = r.random((S, S)) < soft * 0.6
        a = np.maximum(m, speck.astype(np.float32))
        # drips
        for _ in range(7):
            x = int(r.integers(4, S - 4))
            col_has = np.where(m[:, x] > 0)[0]
            if len(col_has) == 0:
                continue
            y0 = col_has.max()
            ln = int(r.integers(4, 16))
            a[y0:min(S, y0 + ln), x] = 1.0
        rgb = np.ones((S, S, 3), np.float32) * np.array(c, np.float32) / 255.0
        rgb = shade(rgb, 0.85 + 0.15 * value_noise(S, 6, 310 + i, 2))
        save_rgba(name, rgb, a)
        names.append(name)
    return names


# ================================================================== prop surfaces
def surfaces():
    r = rng(400)
    # cardboard: tape across the middle, an arrow, a stamp
    p = fill((170, 120, 70), 64, 64)
    p = shade(p, 0.9 + 0.15 * value_noise(64, 8, 401, 3))
    p[28:36, :] = col(200, 170, 110)
    p = text(p, "THIS SIDE\nUP", "Silkscreen-Regular.ttf", 8, (70, 40, 20), box=(4, 4, 60, 26), spacing=-1)
    p = text(p, "FRAGILE", "Anton-Regular.ttf", 12, (170, 20, 20), box=(4, 40, 60, 60))
    save("dr_cardboard", grime(p, 402, 0.25))

    # books: three shelves of coloured spines
    p = fill((60, 36, 20), 64, 64)
    for row in range(3):
        y0 = 2 + row * 21
        x = 2
        while x < 62:
            bw = int(r.integers(3, 7))
            bh = int(r.integers(12, 19))
            c = [(150, 20, 20), (20, 60, 140), (30, 100, 40), (200, 170, 60), (90, 30, 90), (220, 220, 200), (20, 20, 20)][int(r.integers(0, 7))]
            p[y0 + 19 - bh:y0 + 19, x:min(62, x + bw)] = col(*c)
            p[y0 + 19 - bh + 2:y0 + 19 - bh + 3, x:min(62, x + bw)] = col(230, 200, 100)
            x += bw + (1 if r.random() < 0.3 else 0)
        p[y0 + 19:y0 + 21, :] = col(40, 22, 10)
    save("dr_books", grime(p, 403, 0.2))

    # vending machine front (64x128): glass window with cans, a coin panel, logo
    p = fill((200, 20, 40), 128, 64)
    p = text(p, "JUICE", "Anton-Regular.ttf", 18, (255, 255, 255), box=(2, 2, 62, 24), stroke=(80, 0, 10))
    p[26:104, 4:44] = col(20, 30, 40)
    for row in range(6):
        for k in range(4):
            c = [(255, 220, 0), (0, 200, 120), (255, 120, 200), (120, 200, 255), (255, 80, 20)][(row + k) % 5]
            y, x = 29 + row * 12, 6 + k * 9
            p[y:y + 9, x:x + 6] = col(*c)
            p[y + 3:y + 5, x:x + 6] = col(255, 255, 255)
        p[29 + row * 12 + 9:29 + row * 12 + 10, 4:44] = col(120, 120, 130)
    p[26:104, 48:60] = col(60, 60, 70)
    for k in range(5):
        p[32 + k * 8:36 + k * 8, 50:58] = col(180, 180, 190)
    p[86:92, 50:58] = col(10, 10, 10)
    p[108:122, 8:56] = col(15, 15, 15)
    save("dr_vending", grime(p, 404, 0.2))

    # screens: terminal text, and a staring face in static
    p = fill((5, 20, 10), 64, 64)
    lines = ["> QUOTA", "  UNMET", "> SNIRB", "  FOUND?", "> Y/N_"]
    p = text(p, "\n".join(lines), "VT323-Regular.ttf", 13, (60, 255, 120), xy=(3, 1), spacing=-2)
    yy = np.mgrid[0:64, 0:64][0]
    p[(yy % 2) == 0] *= 0.7
    save("dr_screen", p, q=False)
    st = r.random((64, 64))[..., None] * np.ones(3) * 0.8
    face = snirby_photo(40, 40)
    st[12:52, 12:52] = st[12:52, 12:52] * 0.45 + face * 0.55
    st[(yy % 2) == 0] *= 0.7
    save("dr_screen2", st.astype(np.float32), q=False)
    # CRT: a bright test card
    p = fill((10, 10, 10), 64, 64)
    bars = [(255, 255, 255), (255, 255, 0), (0, 255, 255), (0, 255, 0), (255, 0, 255), (255, 0, 0), (0, 0, 255)]
    for k, c in enumerate(bars):
        p[4:40, 4 + k * 8:12 + k * 8] = col(*c)
    p = text(p, "NO SIGNAL\nNO GOD", "Silkscreen-Regular.ttf", 8, (255, 255, 255), box=(2, 42, 62, 62), spacing=-1)
    save("dr_crt", p, q=False)

    # fabric (couches, beds, gurney pads)
    yy, xx = np.mgrid[0:64, 0:64]
    p = fill((110, 90, 70), 64, 64)
    p = shade(p, 0.85 + 0.2 * value_noise(64, 16, 405, 2) + 0.06 * ((xx + yy) % 4 < 2))
    save("dr_fabric", grime(p, 406, 0.35))

    # paper: memo with scribbled lines
    p = fill((235, 232, 220), 64, 64)
    p = text(p, "MEMO", "Silkscreen-Regular.ttf", 8, (20, 20, 20), box=(2, 2, 62, 12))
    for k in range(9):
        ln = int(r.integers(20, 56))
        p[16 + k * 5, 5:5 + ln] = col(60, 60, 80)
    save("dr_paper", p)

    # filing cabinet: three drawers with handles and labels
    p = fill((120, 125, 115), 64, 64)
    for k in range(3):
        y0 = 2 + k * 21
        p[y0:y0 + 19, 3:61] = col(140, 145, 135)
        p[y0, 3:61] = col(180, 185, 175); p[y0 + 18, 3:61] = col(70, 72, 66)
        p[y0 + 9:y0 + 12, 24:40] = col(60, 60, 60)
        p[y0 + 3:y0 + 7, 26:38] = col(240, 235, 210)
    save("dr_cabinet", grime(p, 407, 0.3))

    # locker (64x128): two doors with vents and padlocks
    p = fill((60, 90, 120), 128, 64)
    for d in range(2):
        x0 = 2 + d * 31
        p[2:126, x0:x0 + 29] = col(70, 105, 140)
        for v in range(6):
            p[10 + v * 4:12 + v * 4, x0 + 6:x0 + 23] = col(20, 30, 40)
        p[60:68, x0 + 22:x0 + 26] = col(200, 180, 60)
        p[2:126, x0] = col(110, 140, 170); p[2:126, x0 + 28] = col(40, 60, 80)
    p = text(p, "13", "Silkscreen-Regular.ttf", 8, (255, 255, 255), box=(4, 40, 30, 52))
    save("dr_locker", grime(p, 408, 0.35))


if __name__ == "__main__":
    posters()
    signs()
    graffiti()
    surfaces()
