"""Synthesises every sound effect in Gorbino's Quest.

Run: python3 tools/gen_audio.py   -> assets/sounds/*.wav (22050 Hz, 16-bit mono)
"""
import os
import wave
import numpy as np
from scipy import signal

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sounds")
os.makedirs(OUT, exist_ok=True)
SR = 22050
R = np.random.default_rng(1234)


def t_(d):
    return np.arange(int(SR * d)) / SR


# These come from the user's own recordings (tools/import_user_audio.py).
USER_SOUNDS = {"pistol_fire", "mg_fire", "shotgun_fire", "ssg_fire", "enemy_gun"}


def save(name, x, gain=0.9, crush=None):
    if name in USER_SOUNDS:
        return
    x = np.asarray(x, np.float64)
    if crush:
        q = 2 ** crush
        x = np.round(x * q) / q
    peak = np.max(np.abs(x)) + 1e-9
    x = x / peak * gain
    # tiny fade to avoid clicks
    f = min(64, len(x) // 4)
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def noise(d):
    return R.uniform(-1, 1, int(SR * d))


def env(n, a=0.002, d=0.1, s=0.0, curve=4.0):
    """attack then exponential-ish decay to sustain over n samples."""
    x = np.arange(n) / SR
    att = np.clip(x / max(a, 1e-5), 0, 1)
    dec = s + (1 - s) * np.exp(-np.maximum(x - a, 0) * curve / max(d, 1e-5))
    return att * dec


def lp(x, fc, order=2):
    fc = np.clip(fc, 20, SR / 2 - 100)
    b, a = signal.butter(order, fc / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def hp(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR / 2 - 200) / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def sweep_lp(x, f0, f1):
    """Time-varying one-pole lowpass from f0 to f1 (log sweep)."""
    n = len(x)
    fc = f0 * (f1 / f0) ** (np.arange(n) / n)
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.zeros(n)
    s = 0.0
    for i in range(n):
        s = (1 - a[i]) * x[i] + a[i] * s
        y[i] = s
    return y


def osc(freq, d, kind="sine", phase=0.0):
    n = int(SR * d)
    if np.isscalar(freq):
        freq = np.full(n, float(freq))
    ph = np.cumsum(freq) / SR + phase
    if kind == "sine":
        return np.sin(2 * np.pi * ph)
    if kind == "saw":
        return 2 * (ph % 1) - 1
    if kind == "square":
        return np.sign(np.sin(2 * np.pi * ph))
    if kind == "tri":
        return 2 * np.abs(2 * (ph % 1) - 1) - 1
    raise ValueError(kind)


def dist(x, k=3.0):
    return np.tanh(x * k) / np.tanh(k)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def pad(x, d):
    return np.concatenate([x, np.zeros(int(SR * d))])


def delay(x, t, fb=0.3, wet=0.4, n=4):
    out = np.concatenate([x, np.zeros(int(SR * t * n))])
    for k in range(1, n + 1):
        off = int(SR * t * k)
        out[off:off + len(x)] += x * (fb ** k) * wet / fb
    return out


# ---------------------------------------------------------------- formant voice
VOWELS = {
    "a": (750, 1200, 2500), "o": (500, 850, 2400), "u": (330, 800, 2300), "e": (450, 1900, 2600),
    "i": (300, 2300, 3000), "r": (450, 1250, 1600), "n": (280, 1700, 2600), "m": (280, 1000, 2400),
}


def voice(segments, base_pitch, pitch_curve=None, breath=0.05, growl=0.0, kind="saw"):
    """segments: list of (phoneme, duration). Pitch curve: function t->multiplier."""
    total = sum(d for _, d in segments)
    n = int(SR * total)
    tt = np.arange(n) / SR
    pc = pitch_curve(tt / total) if pitch_curve else np.ones(n)
    f0 = base_pitch * pc * (1 + 0.02 * np.sin(2 * np.pi * 6 * tt))
    if growl:
        f0 = f0 * (1 + growl * np.sin(2 * np.pi * 37 * tt))
    src = osc(f0, total, kind) + breath * R.uniform(-1, 1, n)
    # per-sample formant targets (interpolated between segments)
    marks = []
    acc = 0
    for ph, d in segments:
        marks.append((acc + d / 2, VOWELS.get(ph, VOWELS["a"])))
        acc += d
    times = np.array([m[0] for m in marks])
    out = np.zeros(n)
    amp = np.ones(n)
    # consonant amplitude shaping
    acc = 0
    for ph, d in segments:
        i0, i1 = int(acc * SR), int((acc + d) * SR)
        if ph in ("b", "g", "k", "p", "t", "d"):
            amp[i0:i1] = np.linspace(1, 0.05, i1 - i0) if ph in ("b", "p") else 0.2
        if ph == "s":
            amp[i0:i1] = 0.0
        acc += d
    block = 256
    for k in range(3):
        fk = np.interp(tt, times, [m[1][k] for m in marks])
        y = np.zeros(n)
        zi = None
        for s0 in range(0, n, block):
            fc = fk[min(s0 + block // 2, n - 1)]
            bw = 80 + k * 60
            b, a = signal.iirpeak(fc / (SR / 2), fc / bw)
            seg = src[s0:s0 + block]
            if zi is None:
                zi = signal.lfilter_zi(b, a) * 0
            yy, zi = signal.lfilter(b, a, seg, zi=zi)
            y[s0:s0 + block] = yy
        out += y * [1.0, 0.7, 0.35][k]
    out *= amp
    # add consonant noises
    acc = 0
    for ph, d in segments:
        i0 = int(acc * SR)
        if ph == "s":
            nz = hp(R.uniform(-1, 1, int(SR * d)), 4000) * 0.6
            out[i0:i0 + len(nz)] += nz
        if ph in ("g", "k"):
            nz = bp(R.uniform(-1, 1, int(SR * 0.03)), 1200, 3000) * 0.8
            out[i0:i0 + len(nz)] += nz
        if ph in ("b", "p", "d", "t"):
            nz = lp(R.uniform(-1, 1, int(SR * 0.02)), 800) * 0.8
            j = int((acc + d) * SR) - len(nz)
            out[max(0, j):max(0, j) + len(nz)] += nz[:len(out[max(0, j):max(0, j) + len(nz)])]
        acc += d
    return out * env(n, 0.01, total, 0.6, 1.0)


# ---------------------------------------------------------------- weapons
def gun_shot(d=0.35, body=110, crack=2500, noise_d=0.18, boom=1.0, crush=None):
    n = int(SR * d)
    nz = noise(d)
    crack_ = hp(nz, crack) * env(n, 0.001, 0.03, 0, 3)
    mid = bp(nz, 300, 3000) * env(n, 0.001, noise_d, 0, 3)
    thump = osc(body * np.exp(-t_(d) * 18) + 40, d) * env(n, 0.001, 0.12, 0, 3) * boom
    return dist(crack_ * 0.7 + mid + thump * 1.2, 2.5)


def weapons():
    save("pistol_fire", gun_shot(0.3, 130, 3000, 0.12, 0.8), crush=7)
    s = gun_shot(0.7, 80, 1800, 0.35, 1.4)
    s = s + 0.3 * lp(noise(0.7), 400) * env(int(SR * 0.7), 0.01, 0.4, 0, 2)
    save("shotgun_fire", s, crush=7)
    second = np.concatenate([np.zeros(int(SR * 0.012)), gun_shot(0.9, 75, 1700, 0.45, 1.6) * 0.8])
    s = mix(gun_shot(0.9, 60, 1500, 0.5, 1.8), second)
    s = mix(s, 0.5 * lp(noise(0.9), 300) * env(int(SR * 0.9), 0.01, 0.6, 0, 2))
    save("ssg_fire", dist(s, 2.0), crush=6)
    save("mg_fire", gun_shot(0.18, 150, 3500, 0.07, 0.7), crush=7)
    # rocket: thump + whoosh
    n = int(SR * 0.8)
    wh = sweep_lp(noise(0.8), 3000, 200) * env(n, 0.02, 0.6, 0, 2)
    th = osc(90 * np.exp(-t_(0.8) * 10) + 30, 0.8) * env(n, 0.001, 0.15, 0, 3)
    save("rocket_fire", dist(wh * 1.5 + th * 1.2, 2), crush=7)
    # plasma: fm zap
    d = 0.25
    f = 1600 * np.exp(-t_(d) * 14) + 200
    mod = osc(f * 1.5, d) * 3
    z = np.sin(2 * np.pi * np.cumsum(f) / SR + mod) * env(int(SR * d), 0.001, 0.18, 0, 3)
    save("plasma_fire", z + 0.2 * hp(noise(d), 5000) * env(int(SR * d), 0.001, 0.04, 0, 3), crush=6)
    # mechanical sounds
    def click(f=3000, d=0.03, lvl=1.0):
        return bp(noise(d), f * 0.6, f * 1.4) * env(int(SR * d), 0.0005, d * 0.5, 0, 4) * lvl
    def clack(f=900, d=0.08):
        return mix(click(2600, 0.02), bp(noise(d), f * 0.5, f * 1.5) * env(int(SR * d), 0.001, 0.05, 0, 4) + osc(f / 3, d) * env(int(SR * d), 0.001, 0.03, 0, 4) * 0.5)
    def seq(*items):
        out = np.zeros(int(SR * 2))
        end = 0
        for at, snd in items:
            i = int(at * SR)
            out[i:i + len(snd)] += snd
            end = max(end, i + len(snd))
        return out[:end]
    save("pistol_reload", seq((0.0, click(2000, 0.04)), (0.08, clack(700)), (0.55, clack(1100)), (0.75, click(3500, 0.03))))
    save("shell_load", seq((0.0, clack(1300, 0.06)), (0.04, click(4000, 0.02, 0.5))))
    save("shotgun_pump", seq((0.0, clack(600, 0.12)), (0.16, clack(900, 0.1))))
    save("ssg_open", seq((0.0, clack(500, 0.15)), (0.05, click(2500, 0.05))))
    save("ssg_load", seq((0.0, clack(1200, 0.08)), (0.12, clack(1300, 0.08))))
    save("ssg_close", seq((0.0, clack(700, 0.15)), (0.02, osc(220, 0.1) * env(int(SR * 0.1), 0.001, 0.05) * 0.4)))
    save("mg_reload", seq((0.0, clack(500, 0.1)), (0.1, click(1500, 0.05)), (0.6, clack(800, 0.12)), (0.85, clack(1200, 0.1))))
    save("rocket_reload", seq((0.0, clack(400, 0.2)), (0.25, osc(120, 0.2) * env(int(SR * 0.2), 0.01, 0.15) * 0.5), (0.5, clack(600, 0.15))))
    d = 1.0
    hiss = hp(noise(d), 3000) * env(int(SR * d), 0.01, 0.8, 0, 1.5)
    save("plasma_vent", hiss + 0.3 * osc(80 + 40 * t_(d), d, "saw") * env(int(SR * d), 0.01, 0.6))
    save("plasma_overheat", mix(osc(np.linspace(900, 300, int(SR * 0.4)), 0.4, "square") * env(int(SR * 0.4), 0.001, 0.4, 0.3) * 0.4, hiss[:int(SR * 0.4)]), crush=5)
    save("dryfire", click(1800, 0.05))
    save("weapon_switch", seq((0.0, clack(800, 0.08)), (0.1, click(2500, 0.03))))
    # explosions
    d = 1.6
    n = int(SR * d)
    rumble = sweep_lp(noise(d), 2500, 80) * env(n, 0.002, 1.0, 0, 2.5)
    boom = osc(60 * np.exp(-t_(d) * 4) + 25, d) * env(n, 0.001, 0.4, 0, 2)
    crackle = hp(noise(d), 2000) * env(n, 0.001, 0.08, 0, 3) * (R.random(n) > 0.7)
    save("explosion", dist(rumble * 2 + boom * 1.5 + crackle * 0.5, 2.5), crush=7)
    d = 0.5
    n = int(SR * d)
    save("explosion_small", dist(sweep_lp(noise(d), 4000, 300) * env(n, 0.001, 0.3, 0, 3) + osc(np.linspace(600, 100, n), d) * env(n, 0.001, 0.2) * 0.6, 2), crush=6)
    # impacts
    save("hit_wall", bp(noise(0.08), 1500, 6000) * env(int(SR * 0.08), 0.0005, 0.03))
    d = 0.18
    n = int(SR * d)
    sq = lp(noise(d), 900) * env(n, 0.002, 0.1) + osc(np.linspace(300, 90, n), d) * env(n, 0.002, 0.08) * 0.6
    save("hit_flesh", sq)
    save("ricochet", osc(np.linspace(3200, 1800, int(SR * 0.25)), 0.25, "tri") * env(int(SR * 0.25), 0.001, 0.2) * 0.6 + bp(noise(0.25), 2000, 6000) * env(int(SR * 0.25), 0.0005, 0.02))


# ---------------------------------------------------------------- creatures
def creatures():
    # GORBINO: low, rubbery voice
    save("gorb_sight", dist(voice([("g", 0.05), ("o", 0.22), ("r", 0.12), ("b", 0.08)], 120, lambda u: 1.3 - 0.4 * u), 1.6), crush=6)
    save("gorb_sight2", dist(voice([("g", 0.04), ("o", 0.12), ("r", 0.08), ("b", 0.05), ("i", 0.1), ("n", 0.06), ("o", 0.18)], 140, lambda u: 1.0 + 0.4 * np.sin(u * 3)), 1.6), crush=6)
    save("gorb_pain", dist(voice([("u", 0.08), ("a", 0.14)], 180, lambda u: 1.4 - 0.5 * u, growl=0.1), 2.0), crush=6)
    save("gorb_death", dist(voice([("g", 0.04), ("o", 0.3), ("r", 0.25), ("b", 0.1), ("u", 0.3)], 130, lambda u: 1.3 - 0.85 * u, growl=0.06), 1.7), crush=6)
    save("gorb_idle", voice([("m", 0.1), ("o", 0.25), ("r", 0.15)], 95, lambda u: 1 + 0.1 * np.sin(u * 8)) * 0.8, crush=6)
    save("gorb_attack", dist(voice([("a", 0.08), ("r", 0.1), ("g", 0.05), ("a", 0.1)], 150, lambda u: 1 + 0.6 * u), 2), crush=6)
    save("gorb_big_sight", dist(voice([("g", 0.06), ("o", 0.4), ("r", 0.3), ("b", 0.12)], 62, lambda u: 1.2 - 0.3 * u, growl=0.15), 2.5), crush=6)
    save("gorb_big_death", dist(voice([("g", 0.05), ("o", 0.5), ("r", 0.5), ("u", 0.6)], 70, lambda u: 1.2 - 0.8 * u, growl=0.2), 2.5), crush=6)
    d = 0.25
    n = int(SR * d)
    bite = lp(noise(d), 1500) * env(n, 0.001, 0.08) + osc(np.linspace(200, 60, n), d, "square") * env(n, 0.001, 0.06) * 0.5
    save("gorb_bite", bite)
    # SNIRBY: squeaky, nasal
    save("snirb_sight", dist(voice([("s", 0.07), ("n", 0.05), ("i", 0.15), ("r", 0.08), ("b", 0.05)], 420, lambda u: 1 + 0.5 * u), 1.5), crush=6)
    save("snirb_pain", dist(voice([("i", 0.12), ("e", 0.08)], 700, lambda u: 1.3 - 0.4 * u), 2), crush=6)
    save("snirb_death", dist(voice([("s", 0.06), ("n", 0.06), ("i", 0.2), ("r", 0.2), ("u", 0.25)], 520, lambda u: 1.5 - 1.1 * u), 1.6), crush=6)
    # sniff: 3 short bandpassed noise inhales
    out = np.zeros(int(SR * 0.7))
    for k, at in enumerate((0.0, 0.18, 0.36)):
        d = 0.12
        nz = bp(noise(d), 2500 + k * 300, 6000) * env(int(SR * d), 0.03, 0.06, 0, 2)
        i = int(at * SR)
        out[i:i + len(nz)] += nz
    save("snirb_sniff", out)
    d = 0.3
    n = int(SR * d)
    spit = bp(noise(d), 800, 4000) * env(n, 0.002, 0.15) + osc(np.linspace(900, 300, n), d, "tri") * env(n, 0.001, 0.1) * 0.5
    save("snirb_spit", spit)
    d = 1.0
    n = int(SR * d)
    buzz = osc(38 + 3 * np.sin(2 * np.pi * 3 * t_(d)), d, "saw") * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 19 * t_(d))))
    save("snirb_fly", lp(buzz, 900) * 0.8)
    save("boss_roar", dist(voice([("s", 0.1), ("n", 0.1), ("i", 0.4), ("r", 0.5), ("b", 0.2)], 160, lambda u: 1.0 + 0.3 * np.sin(u * 9), growl=0.25), 3), crush=5)
    save("boss_death", dist(mix(voice([("i", 0.4), ("r", 0.6), ("u", 1.2)], 300, lambda u: 1.6 - 1.4 * u, growl=0.2), sweep_lp(noise(2.2), 3000, 60) * env(int(SR * 2.2), 0.01, 2.0, 0, 1.5)), 2.5), crush=5)
    # projectile whoosh
    d = 0.35
    n = int(SR * d)
    save("proj_launch", sweep_lp(noise(d), 600, 3500) * env(n, 0.02, 0.25) + osc(np.linspace(200, 500, n), d, "tri") * env(n, 0.01, 0.2) * 0.4)
    save("enemy_gun", gun_shot(0.3, 110, 2200, 0.12, 0.7), crush=6)


# ---------------------------------------------------------------- player
def player():
    save("player_pain", dist(voice([("u", 0.06), ("a", 0.1)], 150, lambda u: 1.2 - 0.3 * u, breath=0.3, kind="square"), 2.0) * 0.8, crush=5)
    save("player_pain2", dist(voice([("e", 0.06), ("u", 0.12)], 135, lambda u: 1.1 - 0.2 * u, breath=0.3, kind="square"), 2.0) * 0.8, crush=5)
    save("player_death", dist(voice([("a", 0.2), ("u", 0.5)], 140, lambda u: 1.2 - 0.6 * u, breath=0.3, growl=0.1, kind="square"), 2.0), crush=5)
    save("player_jump", voice([("u", 0.08)], 160, lambda u: 1 + 0.2 * u, breath=0.5) * 0.4, crush=5)
    d = 0.15
    n = int(SR * d)
    save("player_land", lp(noise(d), 400) * env(n, 0.001, 0.06) + osc(np.linspace(110, 50, n), d) * env(n, 0.001, 0.05) * 0.8)
    for i, (lo, hi) in enumerate([(200, 1200), (300, 1600), (150, 900)]):
        d = 0.09
        save("step%d" % i, bp(noise(d), lo, hi) * env(int(SR * d), 0.002, 0.03) * 0.6)
    d = 0.12
    save("step_metal", bp(noise(d), 1500, 5000) * env(int(SR * d), 0.001, 0.03) + osc(1700, d, "tri") * env(int(SR * d), 0.001, 0.02) * 0.2)
    save("step_squish", lp(noise(0.14), 700) * env(int(SR * 0.14), 0.01, 0.08) + osc(np.linspace(180, 90, int(SR * 0.14)), 0.14) * env(int(SR * 0.14), 0.01, 0.05) * 0.4)
    d = 0.4
    n = int(SR * d)
    save("splash", sweep_lp(noise(d), 4000, 500) * env(n, 0.005, 0.25))
    save("liquid_burn", hp(noise(0.3), 2500) * env(int(SR * 0.3), 0.01, 0.2) + osc(np.linspace(400, 200, int(SR * 0.3)), 0.3, "square") * 0.15 * env(int(SR * 0.3), 0.01, 0.2), crush=5)


# ---------------------------------------------------------------- items / world / ui
def items():
    def arp(notes, step=0.05, kind="square", d=0.09, lvl=1.0):
        out = np.zeros(int(SR * (step * len(notes) + d + 0.05)))
        for k, f in enumerate(notes):
            s = osc(f, d, kind) * env(int(SR * d), 0.002, d * 0.6, 0, 3) * lvl
            i = int(k * step * SR)
            out[i:i + len(s)] += s
        return out
    save("pickup_item", arp([660, 880], 0.05), crush=5)
    save("pickup_health", arp([523, 659, 784], 0.045), crush=5)
    save("pickup_armor", arp([392, 523, 392, 659], 0.04, "tri"), crush=5)
    save("pickup_ammo", mix(arp([300, 450], 0.04, "square", 0.06), bp(noise(0.08), 1000, 3000) * env(int(SR * 0.08), 0.001, 0.03) * 0.5), crush=5)
    w = mix(arp([196, 247, 294, 392, 494], 0.06, "saw", 0.14), lp(noise(0.3), 600) * env(int(SR * 0.3), 0.002, 0.15) * 0.5)
    save("pickup_weapon", delay(w, 0.11, 0.35, 0.4, 3), crush=6)
    save("pickup_key", delay(arp([784, 988, 1175, 1568], 0.07, "tri", 0.2), 0.14, 0.4, 0.5, 4), crush=6)
    save("pickup_mega", delay(arp([262, 330, 392, 523, 659, 784, 1047], 0.05, "saw", 0.2), 0.1, 0.4, 0.5, 4), crush=6)
    # secret: eerie descending whole-tone chime
    save("secret", delay(arp([1397, 1245, 1109, 988, 880, 1568], 0.12, "sine", 0.6), 0.18, 0.5, 0.6, 5))
    # doors
    d = 1.0
    n = int(SR * d)
    motor = osc(55 + 10 * t_(d), d, "saw") * 0.5 + bp(noise(d), 100, 900) * 0.8
    motor *= env(n, 0.05, 0.9, 0.8, 1.0)
    clunk = np.zeros(n)
    c = lp(noise(0.12), 500) * env(int(SR * 0.12), 0.001, 0.05) * 2
    clunk[:len(c)] += c
    clunk[n - len(c):] += c
    save("door_open", dist(motor + clunk, 1.5), crush=6)
    save("door_locked", osc(110, 0.35, "square") * env(int(SR * 0.35), 0.002, 0.3, 0.6) * 0.6 + osc(116, 0.35, "square") * 0.4 * env(int(SR * 0.35), 0.002, 0.3, 0.6), crush=5)
    save("switch", mix(lp(noise(0.08), 1200) * env(int(SR * 0.08), 0.001, 0.03) * 2, osc(880, 0.15, "square") * env(int(SR * 0.15), 0.01, 0.1) * 0.3), crush=5)
    save("exit", delay(arp([392, 330, 262, 196, 131], 0.09, "saw", 0.3), 0.15, 0.4, 0.4, 3), crush=6)
    d = 1.0
    n = int(SR * d)
    tele = osc(200 * (1 + 4 * t_(d)), d, "sine") * env(n, 0.01, 0.8) + osc(203 * (1 + 4 * t_(d)), d, "saw") * 0.3 * env(n, 0.01, 0.6)
    save("teleport", delay(tele, 0.07, 0.4, 0.4, 3), crush=6)
    save("checkpoint", delay(arp([523, 784, 1047], 0.1, "tri", 0.25), 0.12, 0.4, 0.5, 3), crush=6)
    # UI
    save("menu_move", osc(np.linspace(900, 1200, int(SR * 0.05)), 0.05, "square") * env(int(SR * 0.05), 0.001, 0.04) * 0.6, crush=4)
    save("menu_select", arp([440, 660, 990], 0.035, "square", 0.06), crush=4)
    save("menu_back", arp([660, 330], 0.04, "square", 0.06), crush=4)
    save("tally", osc(1200, 0.03, "square") * env(int(SR * 0.03), 0.001, 0.02) * 0.5, crush=4)
    save("tally_done", mix(lp(noise(0.25), 800) * env(int(SR * 0.25), 0.001, 0.1) * 1.5, arp([220, 330], 0.03, "square", 0.1)), crush=5)
    save("message", osc(1500, 0.06, "square") * env(int(SR * 0.06), 0.001, 0.05) * 0.4, crush=4)
    save("stamp", dist(lp(noise(0.3), 300) * env(int(SR * 0.3), 0.001, 0.1) * 2 + osc(np.linspace(120, 40, int(SR * 0.3)), 0.3) * env(int(SR * 0.3), 0.001, 0.15), 2))


# ---------------------------------------------------------------- ambience loops (seamless)
def loopify(x, xf=0.5):
    k = int(SR * xf)
    head, body = x[:k], x[k:]
    body[-k:] = body[-k:] * np.linspace(1, 0, k) + head * np.linspace(0, 1, k)
    return body


def ambience():
    d = 9.0
    n = int(SR * d)
    tt = t_(d)
    # village: wind + warped birds
    wind = sweep_lp(noise(d), 300, 600) * (0.6 + 0.4 * np.sin(2 * np.pi * tt / 4.5))
    birds = np.zeros(n)
    for at in R.uniform(0.2, d - 1, 9):
        bd = 0.18
        f = 2400 + 900 * np.sin(2 * np.pi * 14 * t_(bd)) - 2000 * t_(bd)
        s = osc(f, bd, "sine") * env(int(SR * bd), 0.01, 0.1) * 0.25
        i = int(at * SR)
        birds[i:i + len(s)] += s
    save("amb_village", loopify(wind * 0.6 + birds), gain=0.5)
    # industrial: machine hum + clanks
    hum = osc(50, d, "saw") * 0.3 + osc(100.5, d, "square") * 0.1
    hum = lp(hum, 400) * (0.8 + 0.2 * np.sign(np.sin(2 * np.pi * 1.5 * tt)))
    clank = np.zeros(n)
    for at in np.arange(0.3, d - 0.5, 1.5):
        c = bp(noise(0.2), 600, 3000) * env(int(SR * 0.2), 0.001, 0.08) * 0.5
        i = int(at * SR)
        clank[i:i + len(c)] += c
    save("amb_industrial", loopify(hum + clank + lp(noise(d), 200) * 0.3), gain=0.5)
    # mines: drips + low wind
    drips = np.zeros(n)
    for at in R.uniform(0.1, d - 0.5, 12):
        dd = 0.12
        s = osc(np.linspace(1800, 900, int(SR * dd)) * R.uniform(0.7, 1.3), dd, "sine") * env(int(SR * dd), 0.001, 0.05) * 0.4
        i = int(at * SR)
        drips[i:i + len(s)] += s
    rumble = lp(noise(d), 120) * 2.0
    save("amb_mines", loopify(delay(drips, 0.21, 0.4, 0.5, 3)[:n] + rumble), gain=0.5)
    # hq: fluorescent buzz + distant phone trill
    buzz = lp(osc(120, d, "saw"), 2000) * 0.15 + hp(noise(d), 6000) * 0.03
    trill = np.zeros(n)
    for at in (2.0, 6.5):
        td = 0.6
        s = osc(1400, td, "square") * (np.sign(np.sin(2 * np.pi * 16 * t_(td))) > 0) * env(int(SR * td), 0.01, 0.5, 0.5) * 0.08
        i = int(at * SR)
        trill[i:i + len(s)] += lp(s, 2500)
    save("amb_hq", loopify(buzz + trill), gain=0.45)
    # facility: bubbling vats + hum
    bub = np.zeros(n)
    for at in R.uniform(0.1, d - 0.3, 40):
        bd = 0.06
        s = osc(np.linspace(300, 900, int(SR * bd)) * R.uniform(0.8, 1.4), bd, "sine") * env(int(SR * bd), 0.005, 0.03) * 0.3
        i = int(at * SR)
        bub[i:i + len(s)] += s
    save("amb_facility", loopify(bub + lp(osc(60, d, "saw"), 300) * 0.25), gain=0.5)
    # dimension: detuned whisper drone
    dr = osc(110 * (1 + 0.01 * np.sin(2 * np.pi * 0.3 * tt)), d, "saw") + osc(116.5, d, "saw") + osc(164.8, d, "saw") * 0.5
    dr = lp(dr, 700) * 0.2
    whis = bp(noise(d), 1500, 4000) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.7 * tt)) ** 4 * 0.3
    save("amb_dimension", loopify(dr + whis), gain=0.5)


if __name__ == "__main__":
    weapons()
    creatures()
    player()
    items()
    ambience()
    print("sounds:", len(os.listdir(OUT)))
