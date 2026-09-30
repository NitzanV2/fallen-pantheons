"""Synthesizes the game's three music loops into game/music/*.ogg.

  theme.ogg   general screens (menu, map, events): slow D minor harp, pads, bell and choir.
  battle.ogg  regular fights: driving string ostinato, taiko, brass melody.
  boss.ogg    boss fights: faster, Phrygian (Eb over D), pounding drums, brass and choir chant.

Each loop is rendered three times back to back and the middle pass is kept, so reverb and
release tails (and slightly early notes of the next pass) are already present at its edges.

Usage: py -3 tools/compose_music.py   (needs numpy, scipy, soundfile)
"""
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "game" / "music"
rng = np.random.default_rng(11)

NOTES = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
         "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def midi(name: str) -> int:
    return 12 * (int(name[-1]) + 1) + NOTES[name[:-1]]


def hz(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


def chord(name: str) -> tuple[int, int]:
    """Root (MIDI, around octave 3) and third interval of a chord like 'Dm' or 'Bb'."""
    minor = name.endswith("m")
    root = midi((name[:-1] if minor else name) + "3")
    if root > midi("F#3"):
        root -= 12
    return root, 3 if minor else 4


def parse(line: str) -> list[tuple[str, float]]:
    out = []
    for token in line.split():
        name, beats = token.split(":")
        out.append((name, float(beats)))
    return out


# ------------------------------------------------------------------ dsp helpers

def times(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * SR)) / SR


def lowpass(x, cutoff, order=2):
    b, a = signal.butter(order, min(cutoff, SR * 0.45) / (SR / 2))
    return signal.lfilter(b, a, x)


def highpass(x, cutoff, order=2):
    b, a = signal.butter(order, cutoff / (SR / 2), btype="high")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], btype="band")
    return signal.lfilter(b, a, x)


def saw(f, t, phase=0.0):
    return 2 * ((f * t + phase) % 1.0) - 1


def envelope(n, attack, release, hold):
    """Linear attack, sustain for `hold` seconds, then an exponential release."""
    e = np.ones(n)
    a = min(n, max(1, int(attack * SR)))
    e[:a] = np.linspace(0, 1, a)
    start = min(n, int(hold * SR))
    r = n - start
    if r > 0:
        e[start:] *= np.exp(-5 * np.arange(r) / r)
    return e


# ------------------------------------------------------------------ instruments (mono)

def pad(f, dur):
    t = times(dur + 1.8)
    x = sum(saw(f * 2 ** (c / 1200), t, rng.random()) for c in (-8, 0, 7)) / 3
    x = lowpass(x, min(f * 4, 1800)) + 0.3 * np.sin(2 * np.pi * f * t)
    return x * envelope(len(t), 0.9, 1.8, dur)


def choir(f, dur):
    t = times(dur + 1.2)
    out = np.zeros(len(t))
    for v, cents in enumerate((-6, 0, 5)):
        ff = f * 2 ** (cents / 1200)
        vib = 1 + 0.004 * np.sin(2 * np.pi * (5 + v * 0.3) * t + v)
        phase = 2 * np.pi * np.cumsum(ff * vib) / SR
        for k in range(1, 16):
            fk = ff * k
            if fk > 8000:
                break
            amp = (np.exp(-((fk - 750) / 260) ** 2) + 0.7 * np.exp(-((fk - 1150) / 300) ** 2)
                   + 0.25 * np.exp(-((fk - 2600) / 400) ** 2) + 0.15 / k)
            out += amp * np.sin(k * phase)
    return out / 3 * envelope(len(t), 0.35, 1.2, dur)


def harp(f, dur):
    t = times(2.5)
    out = sum(np.sin(2 * np.pi * f * k * t) / k ** 1.4 * np.exp(-t * (1.2 + 0.9 * k))
              for k in range(1, 9) if f * k < 12000)
    return out * np.minimum(1, t / 0.003)


def bell(f, dur):
    t = times(3.5)
    x = np.sin(2 * np.pi * f * t + 2.5 * np.exp(-t * 2) * np.sin(2 * np.pi * f * 3.5 * t))
    x += 0.3 * np.sin(2 * np.pi * f * 2.01 * t) * np.exp(-t * 2)
    return x * np.exp(-t * 1.1) * np.minimum(1, t / 0.002)


def bass(f, dur):
    t = times(dur + 0.25)
    x = np.sin(2 * np.pi * f * t) + 0.35 * lowpass(saw(f, t), 500)
    return x * envelope(len(t), 0.01, 0.25, dur)


def strings(f, dur):
    """Short bowed staccato for ostinatos."""
    t = times(dur + 0.15)
    x = (saw(f * 1.003, t, rng.random()) + saw(f * 0.997, t, rng.random())) / 2
    return lowpass(x, 2800) * np.exp(-t / (dur * 0.6)) * np.minimum(1, t / 0.004)


def brass(f, dur):
    t = times(dur + 0.35)
    x = saw(f, t) + 0.5 * saw(f * 1.004, t, 0.3)
    bright = np.clip(np.clip(t / 0.08, 0, 1) * np.exp(-t * 1.5) * 1.3, 0, 1)
    y = lowpass(x, 600) * (1 - bright) + lowpass(x, 3200) * bright
    return y * envelope(len(t), 0.05, 0.35, dur)


def taiko(big=True):
    t = times(1.0)
    f0, f1 = (70, 45) if big else (100, 68)
    freq = f1 + (f0 - f1) * np.exp(-t * 18)
    body = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t * (5 if big else 8))
    skin = lowpass(rng.standard_normal(len(t)), 1200) * np.exp(-t * 30) * 0.4
    return body + skin


def frame_drum():
    t = times(0.8)
    freq = 120 + 60 * np.exp(-t * 25)
    body = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t * 7)
    return body + bandpass(rng.standard_normal(len(t)), 200, 1500) * np.exp(-t * 20) * 0.5


def snare():
    t = times(0.35)
    x = bandpass(rng.standard_normal(len(t)), 300, 4000) * np.exp(-t * 16)
    return x + 0.4 * np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25)


def hat():
    t = times(0.12)
    return highpass(rng.standard_normal(len(t)), 7000) * np.exp(-t * 60)


# ------------------------------------------------------------------ mixing

class Song:
    """A set of named stereo groups, balanced against each other when rendered."""

    def __init__(self, seconds: float):
        self.n = int(seconds * SR)
        self.groups: dict[str, np.ndarray] = {}

    def add(self, group, x, time, gain=1.0, pan=0.0):
        buf = self.groups.setdefault(group, np.zeros((2, self.n)))
        i = max(0, int((time + rng.normal(0, 0.003)) * SR))
        end = min(i + len(x), self.n)
        x = x[:end - i] * gain * (1 + rng.normal(0, 0.05))
        buf[0, i:end] += x * np.cos((pan + 1) * np.pi / 4)
        buf[1, i:end] += x * np.sin((pan + 1) * np.pi / 4)

    def line(self, group, instr, line, t0, beat, gain=1.0, pan=0.0, shift=0):
        t = t0
        for name, beats in parse(line):
            if name != "R":
                self.add(group, instr(hz(midi(name) + shift), beats * beat), t, gain, pan)
            t += beats * beat


def reverb(buf, seconds, mix):
    t = times(seconds)
    wet = []
    for c in range(2):
        ir = lowpass(rng.standard_normal(len(t)) * np.exp(-t * 6.9 / seconds), 6000)
        ir /= np.sqrt(np.sum(ir ** 2))
        wet.append(signal.fftconvolve(buf[c], ir)[:buf.shape[1]])
    return buf * (1 - mix) + np.array(wet) * mix


def active_rms(x):
    """RMS over the parts where the group is actually playing."""
    mono = x.mean(0)
    w = int(0.05 * SR)
    r = np.sqrt((mono[:len(mono) // w * w].reshape(-1, w) ** 2).mean(1))
    if r.max() == 0:
        return 1.0
    active = r[r > r.max() * 0.05]
    return float(np.sqrt((active ** 2).mean()))


def render(name, loop_seconds, compose, levels, drum_groups=("drums",)):
    global rng
    song = Song(3 * loop_seconds + 4)
    for k in range(3):
        # The passes must be identical so the middle one continues seamlessly into itself.
        rng = np.random.default_rng(11)
        compose(song, k * loop_seconds)
    rng = np.random.default_rng(12)
    a, b = int(loop_seconds * SR), int(2 * loop_seconds * SR)
    mix = np.zeros((2, b - a))
    for group, buf in song.groups.items():
        wet = reverb(buf, 1.2, 0.15) if group in drum_groups else reverb(buf, 3.0, 0.35)
        seg = wet[:, a:b]
        mix += seg * (10 ** (levels[group] / 20) * 0.1 / active_rms(seg))
    mix *= 0.16 / np.sqrt((mix ** 2).mean())
    mix = np.tanh(mix * 1.1) * 0.95
    OUT.mkdir(parents=True, exist_ok=True)
    # libsndfile's Vorbis encoder overflows the stack on large single writes, so write in blocks.
    with sf.SoundFile(OUT / f"{name}.ogg", "w", SR, 2, format="OGG", subtype="VORBIS") as f:
        for i in range(0, mix.shape[1], 8192):
            f.write(mix[:, i:i + 8192].T)
    print(f"{name}.ogg  {loop_seconds:.1f}s")


# ------------------------------------------------------------------ songs

def theme(song: Song, off: float) -> None:
    beat = 60 / 72
    bar = 4 * beat
    prog = ["Dm", "Bb", "F", "C", "Dm", "Bb", "Gm", "A", "Bb", "F", "Gm", "Dm", "Bb", "C", "A", "A"]
    for i, c in enumerate(prog):
        t0 = off + i * bar
        r, third = chord(c)
        for j, m in enumerate([r, r + 7, r + 12, r + 12 + third]):
            song.add("pad", pad(hz(m), bar), t0, 1.0, -0.3 + 0.2 * j)
        song.add("bass", bass(hz(r - 12), bar * 0.95), t0)
        tones = [r + 12, r + 19, r + 24, r + 24 + third, r + 31, r + 36]
        for j, p in enumerate([0, 1, 2, 3, 4, 3, 2, 1]):
            song.add("harp", harp(hz(tones[p]), beat / 2), t0 + j * beat / 2, 1.0 if j else 1.3, -0.4 + 0.15 * p)
        if i % 2 == 0:
            song.add("drums", frame_drum(), t0, 0.6)
        if i >= 8:
            song.add("drums", taiko(True), t0, 1.0)
            song.add("drums", taiko(False), t0 + 2.5 * beat, 0.4)
    song.line("melody", bell, "A4:2 F4:1 E4:1 D4:3 F4:1 C5:2 A4:2 G4:4 A4:1 D5:2 C5:1 Bb4:2 A4:1 G4:1 G4:2 Bb4:1 A4:1 A4:4",
              off, beat, pan=0.15)
    phrase2 = "F5:2 D5:2 C5:2 A4:1 C5:1 D5:2 Bb4:2 A4:4 F4:1 G4:1 A4:1 Bb4:1 C5:2 G4:2 A4:2 C#5:2 R:4"
    song.line("choir", choir, phrase2, off + 8 * bar, beat, shift=-12)
    song.line("melody", bell, phrase2, off + 8 * bar, beat, 0.5, 0.15)


def ostinato(song, r, third, t0, beat, steps, gain=1.0, low=False):
    for s, o in enumerate(steps):
        m = r + (third if o == "t" else o)
        accent = 1.35 if s % 4 == 0 else 1.0
        song.add("ostinato", strings(hz(m), beat / 4 * 0.9), t0 + s * beat / 4, gain * accent, -0.25 if s % 2 else 0.25)
        if low:
            song.add("ostinato", strings(hz(m - 12), beat / 4 * 0.9), t0 + s * beat / 4, 0.6 * gain * accent)


def battle(song: Song, off: float) -> None:
    beat = 60 / 126
    bar = 4 * beat
    cycle = ["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Gm", "A"]
    prog = cycle + cycle + ["Bb", "C", "Dm", "Dm", "Bb", "C", "A", "A"]
    steps = [0, 0, 12, 0, 7, 0, 12, 0, 0, 0, 12, 0, 7, 0, "t", 7]
    for i, c in enumerate(prog):
        t0 = off + i * bar
        r, third = chord(c)
        for j, m in enumerate([r, r + 7, r + 12, r + 12 + third]):
            song.add("pad", pad(hz(m), bar), t0, 1.0, -0.3 + 0.2 * j)
        ostinato(song, r, third, t0, beat, steps)
        for e in (0, 3, 6):
            song.add("bass", bass(hz(r - 12), beat * 0.7), t0 + e * beat / 2)
        song.add("drums", taiko(True), t0, 1.0)
        song.add("drums", taiko(True), t0 + 1.5 * beat, 0.8)
        song.add("drums", taiko(False), t0 + 3 * beat, 0.7)
        for e in (1, 3):
            song.add("drums", snare(), t0 + e * beat, 0.55)
        for s in range(16):
            song.add("drums", hat(), t0 + s * beat / 4, 0.12 if s % 2 else 0.06, 0.3)
        if i % 8 == 7:
            for s in range(8, 16):
                song.add("drums", taiko(False), t0 + s * beat / 4, 0.3 + 0.06 * (s - 8))
        if i >= 16:
            for m in [r + 12, r + 19, r + 24 + third]:
                song.add("choir", choir(hz(m), bar), t0, 0.35)
    song.line("melody", brass, "D4:1.5 E4:0.5 F4:1 A4:1 G4:1.5 F4:0.5 E4:2 D4:1.5 F4:0.5 Bb4:2 C5:1.5 Bb4:0.5 A4:1 G4:1 "
              "A4:1.5 G4:0.5 F4:1 E4:1 D4:2 A3:2 G4:1.5 A4:0.5 Bb4:1 D5:1 C#5:2 A4:2", off + 8 * bar, beat)
    final = "D5:4 E5:4 F5:2 E5:1 D5:1 A4:4 D5:4 E5:2 G5:2 E5:2 C#5:2 A4:4"
    song.line("choir", choir, final, off + 16 * bar, beat, 1.0, 0.0, -12)
    song.line("melody", brass, final, off + 16 * bar, beat, 0.6, 0.0, -12)


def boss(song: Song, off: float) -> None:
    beat = 60 / 144
    bar = 4 * beat
    a = ["Dm", "Dm", "Eb", "Eb", "Dm", "Dm", "C", "A"]
    prog = a + a + ["Bb", "Bb", "C", "C", "Dm", "Dm", "Eb", "A"] + a
    steps = [0, 0, 12, 0, 0, 0, 12, 0, 0, 0, 12, 0, 1, 0, 3, 0]
    for i, c in enumerate(prog):
        t0 = off + i * bar
        r, third = chord(c)
        section = i // 8
        for j, m in enumerate([r, r + 7, r + 12, r + 12 + third]):
            song.add("pad", pad(hz(m), bar), t0, 1.0, -0.3 + 0.2 * j)
        ostinato(song, r, third, t0, beat, steps, low=True)
        for e in range(8):
            song.add("bass", bass(hz(r - 12), beat * 0.4), t0 + e * beat / 2, 1.2 if e % 2 == 0 else 0.8)
        for q in range(4):
            song.add("drums", taiko(True), t0 + q * beat, 1.0 if q == 0 else 0.75)
        if section >= 2:
            for q in range(4):
                song.add("drums", taiko(False), t0 + (q + 0.5) * beat, 0.45)
        for e in (1, 3):
            song.add("drums", snare(), t0 + e * beat, 0.6)
        for s in range(16):
            song.add("drums", hat(), t0 + s * beat / 4, 0.12 if s % 2 else 0.07, 0.3)
        if i % 4 == 3:
            for s in range(8, 16):
                song.add("drums", taiko(False), t0 + s * beat / 4, 0.35 + 0.07 * (s - 8))
        if section >= 1:
            for m in [r - 12, r - 5, r]:
                song.add("brass", brass(hz(m), beat * 1.2), t0, 1.0)
                song.add("brass", brass(hz(m), beat * 0.4), t0 + 1.5 * beat, 0.7)
        if section == 0 and i % 2 == 0:
            song.add("melody", bell(hz(midi("D4")), bar), t0, 0.5)
        if section == 2:
            for m in [r + 12, r + 19, r + 24 + third]:
                song.add("choir", choir(hz(m), bar), t0, 0.35)
    melody = ("D4:1 D4:0.5 D4:0.5 F4:1 A4:1 G4:1 F4:1 D4:2 Eb4:1 Eb4:0.5 Eb4:0.5 G4:1 Bb4:1 Bb4:1 G4:1 Eb4:2 "
              "D4:1 F4:1 A4:1 D5:1 C5:1 A4:1 F4:2 E4:1 G4:1 C5:2 A4:2 C#5:2")
    song.line("melody", brass, melody, off + 8 * bar, beat)
    chant = "D5:4 F5:4 E5:4 G5:4 F5:4 D5:4 Eb5:4 C#5:4"
    song.line("choir", choir, chant, off + 16 * bar, beat, 1.0, 0.0, -12)
    song.line("melody", brass, chant, off + 16 * bar, beat, 0.7, 0.0, -24)
    song.line("melody", brass, melody, off + 24 * bar, beat)
    song.line("choir", choir, melody, off + 24 * bar, beat, 0.6)


if __name__ == "__main__":
    render("theme", 16 * 4 * 60 / 72, theme,
           {"pad": -7, "bass": -12, "harp": -6, "drums": -10, "melody": -5, "choir": -7})
    render("battle", 24 * 4 * 60 / 126, battle,
           {"pad": -10, "ostinato": -5, "bass": -8, "drums": -3, "melody": -4, "choir": -8})
    render("boss", 32 * 4 * 60 / 144, boss,
           {"pad": -10, "ostinato": -5, "bass": -7, "drums": -2, "brass": -7, "melody": -3, "choir": -6})
