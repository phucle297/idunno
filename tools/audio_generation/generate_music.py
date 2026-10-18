#!/usr/bin/env python3
"""Deterministically render original Disaster Party music (seed 297, no dependencies)."""
import hashlib
import math
import random
import struct
import wave
from pathlib import Path

SEED = 297
SAMPLE_RATE = 32000
DURATION_SECONDS = 32
VERSION = 1
ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets" / "audio" / "music"

# Original 16-bar arrangements: MIDI pitches, all timing in sixteenth notes.
MENU = {
    "name": "toy_town_menu",
    "progression": ((60, 64, 67), (57, 60, 64), (53, 57, 60), (55, 59, 62)),
    "melody": (
        ((72, 0, 4), (76, 6, 2), (79, 8, 4), (76, 13, 3)),
        ((72, 0, 4), (69, 6, 2), (76, 8, 4), (72, 13, 3)),
        ((69, 0, 4), (72, 6, 2), (77, 8, 4), (72, 13, 3)),
        ((71, 0, 4), (74, 6, 2), (79, 8, 4), (74, 13, 3)),
    ),
    "bass": (36, 33, 29, 31),
}
GAMEPLAY = {
    "name": "survival_gameplay",
    "progression": ((57, 60, 64), (62, 65, 69), (55, 59, 62), (60, 64, 67)),
    "melody": ((69, 0, 2), (72, 3, 1), (76, 4, 2), (79, 7, 1), (76, 8, 2), (72, 11, 1), (74, 12, 2), (76, 15, 1)),
    "bass": (33, 38, 31, 36),
}


def hz(midi: int) -> float:
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def envelope(local: float, length: float, attack: float, release: float) -> float:
    if local < 0.0 or local >= length:
        return 0.0
    return min(1.0, local / attack) * min(1.0, (length - local) / release)


def sine(freq: float, time: float) -> float:
    return math.sin(math.tau * freq * time)


def mallet(freq: float, local: float, length: float) -> float:
    env = envelope(local, length, 0.008, 0.11) * math.exp(-3.0 * local / length)
    return env * (sine(freq, local) + 0.34 * sine(freq * 2.01, local) + 0.12 * sine(freq * 3.99, local))


def pluck(freq: float, local: float, length: float) -> float:
    env = envelope(local, length, 0.006, 0.18)
    return env * (0.72 * sine(freq, local) + 0.22 * sine(freq * 2, local) + 0.06 * sine(freq * 3, local))


def render(arrangement: dict, rhythmic: bool) -> list[int]:
    random.seed(SEED)
    sample_count = SAMPLE_RATE * DURATION_SECONDS
    samples = [0.0] * sample_count
    beat = 0.5  # 120 BPM; 16 bars are exactly 32 seconds.
    step = beat / 4.0
    for bar in range(16):
        chord = arrangement["progression"][bar % 4]
        bass_note = arrangement["bass"][bar % 4]
        start = bar * 4.0 * beat
        for eighth in range(8):
            if not rhythmic and eighth % 2:
                continue
            event = start + eighth * beat / 2.0
            for note in chord:
                add_voice(samples, event, 0.34, hz(note), 0.075, pluck)
            if rhythmic and eighth % 2 == 1:
                add_voice(samples, event, 0.14, hz(chord[0] + 12), 0.05, mallet)
        for pulse in range(4):
            if not rhythmic and pulse % 2:
                continue
            event = start + pulse * beat
            add_voice(samples, event, 0.46, hz(bass_note), 0.16, lambda f, t, l: envelope(t, l, .01, .1) * (sine(f, t) + .18 * sine(f * .5, t)))
            if rhythmic:
                add_voice(samples, event + step * 2, 0.11, hz(bass_note + 12), 0.07, pluck)
        phrase = arrangement["melody"] if rhythmic else arrangement["melody"][bar % 4]
        for note, offset, length in phrase:
            add_voice(samples, start + offset * step, length * step * 0.92, hz(note + (12 if bar in (7, 15) else 0)), 0.12, mallet)
        if rhythmic:
            for sixteenth in range(16):
                if sixteenth % 4 in (0, 2):
                    add_voice(samples, start + sixteenth * step, 0.035, 110.0, 0.04, lambda f, t, l: envelope(t, l, .001, .02) * sine(f, t))
                if sixteenth % 4 == 2:
                    add_voice(samples, start + sixteenth * step, 0.025, 1900.0, 0.018, lambda f, t, l: envelope(t, l, .001, .01) * (sine(f, t) + sine(f * 1.37, t)))
    # A matched short edge fade prevents any PCM boundary click when the loop restarts.
    edge = int(SAMPLE_RATE * 0.035)
    peak = max(max(samples), -min(samples))
    return [max(-32767, min(32767, round(value / peak * 24500 * min(1.0, index / edge, (sample_count - 1 - index) / edge)))) for index, value in enumerate(samples)]


def add_voice(samples: list[float], start: float, duration: float, frequency: float, gain: float, instrument) -> None:
    first = max(0, int(start * SAMPLE_RATE))
    last = min(len(samples), int((start + duration) * SAMPLE_RATE))
    for index in range(first, last):
        samples[index] += gain * instrument(frequency, index / SAMPLE_RATE - start, duration)


def write_wav(name: str, samples: list[int]) -> Path:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    path = OUTPUT / f"{name}.wav"
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(struct.pack("<%dh" % len(samples), *samples))
    return path


def main() -> None:
    generated = []
    for arrangement, rhythmic in ((MENU, False), (GAMEPLAY, True)):
        path = write_wav(arrangement["name"], render(arrangement, rhythmic))
        generated.append(f"{path.name}:{hashlib.sha256(path.read_bytes()).hexdigest()}")
    print("MUSIC_GENERATION_OK seed=%d version=%d rate=%d duration=%d %s" % (SEED, VERSION, SAMPLE_RATE, DURATION_SECONDS, " ".join(generated)))


if __name__ == "__main__":
    main()
