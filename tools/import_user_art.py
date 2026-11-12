"""Art supplied by the project owner, made ready for the game.

  tools/user_art/new_quest_face.png -> assets/ui/icon_new_face.png
      the grinning red face on the NEW QUEST button, its grey backdrop cut
      away (the red glow round it fades out instead of ending in a hard edge)

Run: python3 tools/import_user_art.py  (then python3 tools/gen_clay.py to
rebuild the buttons)
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage
from texlib import ROOT

SRC = os.path.join(ROOT, "tools", "user_art")
OUT = os.path.join(ROOT, "assets", "ui")


def cut_grey(path, out, inner=0.6, lo=0.06, hi=0.6):
    """Cut a picture out of its flat grey backdrop. The backdrop and the glow
    fading into it are washed-out colours; everything in the face itself is
    strong colour (or, like the white glints, shut inside it)."""
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1.0)
    # the backdrop: everything washed-out that joins up with the edges
    low = sat < inner
    lab, _ = ndimage.label(low)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    outside = np.isin(lab, list(edge))
    t = np.clip((sat - lo) / (hi - lo), 0, 1)
    a = np.where(outside, t * t * (3 - 2 * t), 1.0)
    # take the grey back out of the half-see-through glow
    flat = outside & (sat < 0.03)
    bg = np.median(rgb[flat], axis=0) if np.any(flat) else np.array([139, 137, 139.0])
    safe = np.maximum(a, 1e-3)[..., None]
    col = np.where(a[..., None] < 1.0, (rgb - (1 - a[..., None]) * bg) / safe, rgb)
    img = np.concatenate([np.clip(col, 0, 255), a[..., None] * 255], -1).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(out)
    print("wrote", out)


if __name__ == "__main__":
    cut_grey(os.path.join(SRC, "new_quest_face.png"), os.path.join(OUT, "icon_new_face.png"))
