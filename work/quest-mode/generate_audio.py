#!/usr/bin/env python3

import math
import random
import wave
from array import array
from pathlib import Path

SAMPLE_RATE = 22050
MAX_AMP = 32767
RNG = random.Random(7)


def clamp(value: float) -> int:
    if value > 1.0:
        value = 1.0
    if value < -1.0:
        value = -1.0
    return int(value * MAX_AMP)


def sine(freq: float, t: float) -> float:
    return math.sin(2 * math.pi * freq * t)


def triangle(freq: float, t: float) -> float:
    return (2 / math.pi) * math.asin(math.sin(2 * math.pi * freq * t))


def soft_square(freq: float, t: float) -> float:
    return math.tanh(2.2 * math.sin(2 * math.pi * freq * t))


def envelope(t: float, start: float, duration: float, attack=0.02, release=0.12) -> float:
    if t < start or t > start + duration:
        return 0.0
    local = t - start
    if local < attack:
        return local / attack
    if t > start + duration - release:
        return max(0.0, (start + duration - t) / release)
    return 1.0


def note_frequency(name: str) -> float:
    notes = {
        "C": 0,
        "C#": 1,
        "Db": 1,
        "D": 2,
        "D#": 3,
        "Eb": 3,
        "E": 4,
        "F": 5,
        "F#": 6,
        "Gb": 6,
        "G": 7,
        "G#": 8,
        "Ab": 8,
        "A": 9,
        "A#": 10,
        "Bb": 10,
        "B": 11,
    }
    pitch = name[:-1]
    octave = int(name[-1])
    midi = (octave + 1) * 12 + notes[pitch]
    return 440.0 * (2 ** ((midi - 69) / 12))


def add_note(
    track: list[float],
    start: float,
    duration: float,
    freq: float,
    amp: float,
    voice: str = "sine",
    vibrato: float = 0.0,
):
    end = min(len(track), int((start + duration) * SAMPLE_RATE))
    begin = int(start * SAMPLE_RATE)
    osc = {"sine": sine, "triangle": triangle, "square": soft_square}[voice]

    for index in range(begin, end):
        t = index / SAMPLE_RATE
        env = envelope(t, start, duration)
        mod_freq = freq * (1 + vibrato * 0.01 * math.sin(2 * math.pi * 5 * (t - start)))
        track[index] += amp * env * osc(mod_freq, t)


def add_drum(track: list[float], start: float, duration: float, amp: float, bright=False):
    begin = int(start * SAMPLE_RATE)
    end = min(len(track), int((start + duration) * SAMPLE_RATE))
    for index in range(begin, end):
        t = index / SAMPLE_RATE
        local = t - start
        env = math.exp(-7 * local / duration)
        noise = (RNG.random() * 2 - 1) * env
        tone = math.sin(2 * math.pi * (90 if not bright else 180) * local) * env
        track[index] += amp * (0.7 * tone + 0.3 * noise)


def normalize(samples: list[float], target=0.9) -> array:
    peak = max(max(samples), abs(min(samples)), 1e-6)
    scale = target / peak
    pcm = array("h")
    for sample in samples:
        pcm.append(clamp(sample * scale))
    return pcm


def write_wave(path: Path, samples: list[float]):
    pcm = normalize(samples)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(pcm.tobytes())


def make_ambient(path: Path):
    duration = 36.0
    samples = [0.0] * int(duration * SAMPLE_RATE)
    drone = [note_frequency("D3"), note_frequency("A3"), note_frequency("C4")]
    melody = [
        ("D4", 1.4),
        ("F4", 1.2),
        ("G4", 1.0),
        ("A4", 1.4),
        ("G4", 1.1),
        ("F4", 1.2),
        ("E4", 1.0),
        ("D4", 1.7),
    ]

    for idx, base in enumerate(drone):
        add_note(samples, 0, duration, base, 0.07 - idx * 0.01, "triangle", vibrato=0.8)

    t = 1.2
    while t < duration - 2.0:
        for note, span in melody:
            freq = note_frequency(note)
            add_note(samples, t, span * 0.92, freq, 0.08, "triangle", vibrato=0.7)
            add_note(samples, t, span * 0.92, freq * 0.5, 0.03, "sine")
            t += span
            if t >= duration - 2.0:
                break

    pad_chords = [
        ("D4", "A4", "C5"),
        ("Bb3", "F4", "A4"),
        ("C4", "G4", "Bb4"),
        ("A3", "E4", "G4"),
    ]
    t = 0.0
    for _ in range(3):
        for chord in pad_chords:
            for note in chord:
                add_note(samples, t, 8.0, note_frequency(note), 0.025, "sine")
            t += 8.0

    beat = 0.0
    while beat < duration:
        add_drum(samples, beat, 0.22, 0.09, bright=False)
        if int(beat * 2) % 4 == 3:
            add_drum(samples, beat + 0.35, 0.12, 0.05, bright=True)
        beat += 2.0

    write_wave(path, samples)


def make_discovery(path: Path):
    duration = 1.6
    samples = [0.0] * int(duration * SAMPLE_RATE)
    seq = [("D4", 0.00), ("F4", 0.18), ("A4", 0.36), ("D5", 0.58)]
    for note, start in seq:
        freq = note_frequency(note)
        add_note(samples, start, 0.65, freq, 0.18, "triangle", vibrato=1.2)
        add_note(samples, start, 0.65, freq * 2, 0.05, "sine")
    write_wave(path, samples)


def make_level_up(path: Path):
    duration = 2.6
    samples = [0.0] * int(duration * SAMPLE_RATE)
    seq = [
        ("D4", 0.00),
        ("F4", 0.18),
        ("A4", 0.36),
        ("D5", 0.58),
        ("F5", 0.90),
        ("A5", 1.18),
    ]
    for note, start in seq:
        freq = note_frequency(note)
        add_note(samples, start, 0.7, freq, 0.20, "triangle", vibrato=1.0)
        add_note(samples, start, 0.9, freq * 0.5, 0.06, "sine")
    add_drum(samples, 0.0, 0.28, 0.08)
    add_drum(samples, 0.56, 0.24, 0.08)
    add_drum(samples, 1.10, 0.3, 0.10)
    write_wave(path, samples)


def make_damage(path: Path):
    duration = 1.1
    samples = [0.0] * int(duration * SAMPLE_RATE)
    add_drum(samples, 0.0, 0.32, 0.22)
    add_note(samples, 0.02, 0.5, note_frequency("D3"), 0.14, "square")
    add_note(samples, 0.06, 0.4, note_frequency("C3"), 0.08, "triangle")
    write_wave(path, samples)


def make_rest(path: Path):
    duration = 2.0
    samples = [0.0] * int(duration * SAMPLE_RATE)
    for start, note in [(0.0, "D4"), (0.2, "F4"), (0.4, "A4"), (0.6, "D5")]:
        add_note(samples, start, 1.2, note_frequency(note), 0.12, "sine", vibrato=0.6)
    write_wave(path, samples)


def main():
    base = Path("/Users/mahfouz/Documents/Codex/2026-08-07/how/outputs/quest-audio")
    base.mkdir(parents=True, exist_ok=True)

    make_ambient(base / "quest-ambient.wav")
    make_discovery(base / "quest-discovery.wav")
    make_level_up(base / "quest-level-up.wav")
    make_damage(base / "quest-damage.wav")
    make_rest(base / "quest-rest.wav")

    print(base)


if __name__ == "__main__":
    main()
