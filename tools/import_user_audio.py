"""Converts the user-supplied sounds in tools/user_audio/ into game sounds.

  vag.wav    -> pistol_fire, enemy_gun (pitched down)
  an944.wav  -> mg_fire; layered and pitched down for shotgun_fire / ssg_fire
  canthide / runpig / seeyou -> voice_* (enemy alert lines)
  idk.wav (or idk.mp3) -> enemy_shot: every enemy gun / spit / projectile shot

Run: python3 tools/import_user_audio.py   (needs numpy + scipy)
To use different sounds, replace the files in tools/user_audio/ and rerun.
"""
import os
import subprocess
import tempfile
import wave
import numpy as np
from scipy import signal

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "user_audio")
OUT = os.path.join(ROOT, "assets", "sounds")
SR = 44100


def load(name):
    with wave.open(os.path.join(SRC, name)) as w:
        sr, ch, n = w.getframerate(), w.getnchannels(), w.getnframes()
        x = np.frombuffer(w.readframes(n), np.int16).astype(np.float64).reshape(-1, ch).mean(1) / 32768.0
    if sr != SR:
        x = signal.resample_poly(x, SR, sr)
    return x


def save(name, x, gain=0.95):
    x = np.asarray(x, np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    # trim trailing silence, short fade out
    a = np.abs(x)
    end = len(x) - np.argmax(a[::-1] > 0.003) if np.any(a > 0.003) else len(x)
    x = x[:min(len(x), end + int(SR * 0.05))]
    f = min(len(x) // 4, int(SR * 0.03))
    x[-f:] *= np.linspace(1, 0, f)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    print("wrote", name, "%.2fs" % (len(x) / SR))


def pitch(x, k):
    """Resample to change pitch and length together (tape-style)."""
    return signal.resample(x, int(len(x) / k))


def thump(dur, f0, f1):
    t = np.arange(int(SR * dur)) / SR
    f = f1 + (f0 - f1) * np.exp(-t * 18)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)


def mix(*xs):
    n = max(len(x) for x in xs)
    out = np.zeros(n)
    for x in xs:
        out[:len(x)] += x
    return out


vag = load("vag.wav")
an = load("an944.wav")
save("pistol_fire", vag)
save("mg_fire", an)
save("enemy_gun", pitch(vag, 0.82), 0.8)
save("shotgun_fire", np.tanh(1.6 * mix(pitch(an, 0.72) * 1.0, pitch(vag, 0.6) * 0.6, thump(0.5, 140, 45) * 0.7)))
save("ssg_fire", np.tanh(2.0 * mix(pitch(an, 0.6), pitch(vag, 0.55) * 0.8,
                                   np.concatenate([np.zeros(int(SR * 0.012)), pitch(an, 0.66) * 0.7]),
                                   thump(0.7, 120, 38) * 0.9)))
for v in ("canthide", "runpig", "seeyou"):
    save("voice_" + v, load(v + ".wav"))

# enemy shooting sound: idk.wav, or idk.mp3 decoded with ffmpeg
if os.path.exists(os.path.join(SRC, "idk.wav")):
    save("enemy_shot", load("idk.wav"))
elif os.path.exists(os.path.join(SRC, "idk.mp3")):
    with tempfile.TemporaryDirectory() as td:
        tmp = os.path.join(td, "idk.wav")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", os.path.join(SRC, "idk.mp3"),
                        "-ac", "1", "-ar", str(SR), "-sample_fmt", "s16", tmp], check=True)
        with wave.open(tmp) as w:
            x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float64) / 32768.0
    save("enemy_shot", x)
else:
    print("no tools/user_audio/idk.wav or idk.mp3: enemies keep their built-in shot sounds")
