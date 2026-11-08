"""Prepare the user-supplied creature assets in tools/user_models/ for the game.

  gorbino.png      -> assets/textures/cr_gorb_<variant>.png (one recolour per Gorbino type)
  snirby_face.jpg  -> assets/textures/cr_snirby_face.png and cr_snirby_feet.png

The Gorbino mesh itself lives at assets/models/gorbino/gorbino.fbx; split it with
  godot --headless --path . -s scripts/tools/import_gorbino.gd
"""
import os
import colorsys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "user_models")
OUT = os.path.join(os.path.dirname(HERE), "assets", "textures")

# hue (None = keep), saturation multiplier, value multiplier
VARIANTS = {
    "green": (None, 1.0, 1.15),
    "yellow": (0.135, 1.25, 2.1),
    "red": (0.995, 1.35, 1.7),
    "blue": (0.6, 1.25, 1.75),
    "purple": (0.79, 1.15, 1.8),
    "black": (None, 0.12, 0.6),
}


def rgb_to_hsv(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx = a.max(-1)
    mn = a.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rc = np.where(m, (mx - r) / np.where(m, d, 1), 0)
    gc = np.where(m, (mx - g) / np.where(m, d, 1), 0)
    bc = np.where(m, (mx - b) / np.where(m, d, 1), 0)
    h = np.where(r == mx, bc - gc, np.where(g == mx, 2.0 + rc - bc, 4.0 + gc - rc))
    h = np.where(m, (h / 6.0) % 1.0, 0.0)
    s = np.where(mx > 1e-6, d / np.where(mx > 1e-6, mx, 1), 0)
    return h, s, mx


def hsv_to_rgb(h, s, v):
    i = np.floor(h * 6.0)
    f = h * 6.0 - i
    p = v * (1 - s)
    q = v * (1 - s * f)
    t = v * (1 - s * (1 - f))
    i = i.astype(int) % 6
    out = np.zeros(h.shape + (3,))
    for k, (r, g, b) in enumerate([(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]):
        sel = i == k
        out[sel] = np.stack([r[sel], g[sel], b[sel]], -1)
    return out


def gorbino():
    im = Image.open(os.path.join(SRC, "gorbino.png")).convert("RGB").resize((256, 256), Image.LANCZOS)
    a = np.asarray(im).astype(np.float64) / 255.0
    h, s, v = rgb_to_hsv(a)
    # only the coloured skin is recoloured; eye whites, pupils and glints stay put
    skin = np.clip((s - 0.2) / 0.25, 0.0, 1.0)
    for name, (hue, sm, vm) in VARIANTS.items():
        nh = h if hue is None else (h * (1 - skin) + hue * skin)
        ns = np.clip(s * (1 + (sm - 1) * skin), 0, 1)
        nv = np.clip(v * (1 + (vm - 1) * skin), 0, 1)
        rgb = hsv_to_rgb(nh, ns, nv)
        Image.fromarray((rgb * 255).round().astype(np.uint8)).save(os.path.join(OUT, "cr_gorb_%s.png" % name))
        print("cr_gorb_%s.png" % name)


def snirby():
    im = Image.open(os.path.join(SRC, "snirby_face.jpg")).convert("RGB")
    w, h = im.size
    # the orange swatch in the top-right corner is the shoe colour
    im.crop((int(w * 0.8), 0, w, int(h * 0.2))).resize((32, 32), Image.LANCZOS).save(os.path.join(OUT, "cr_snirby_feet.png"))
    # paint the swatch over with the surrounding blue so it doesn't show on the head
    a = np.asarray(im).astype(np.float64)
    blue = a[int(h * 0.02):int(h * 0.12), int(w * 0.55):int(w * 0.72)].reshape(-1, 3).mean(0)
    a[0:int(h * 0.25), int(w * 0.76):w] = blue
    Image.fromarray(a.round().astype(np.uint8)).save(os.path.join(OUT, "cr_snirby_face.png"))
    print("cr_snirby_face.png, cr_snirby_feet.png")


if __name__ == "__main__":
    gorbino()
    snirby()
